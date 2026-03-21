Here is a deep read of how Binaryen’s RemoveUnusedModuleElements pass works today on main.

At the highest level, this pass is Binaryen’s module-level dead code elimination pass: it removes unused functions, globals, tags, memories, tables, data segments, and element segments. The README describes it as “Global DCE,” and the source file explains its key conceptual distinction: every module element can be in one of three states—unreferenced, referenced but not used, or used. Unreferenced things can be removed outright. Used things must remain intact. Referenced-but-not-used things are the interesting middle case: they must still exist in the IR so references remain valid, but their internals may be discardable. For functions, Binaryen exploits that by replacing the body with unreachable instead of deleting the function entirely. 

1. The core model: “used” is stronger than “referenced”

The pass is built around a very deliberate distinction:

No references at all: remove the element entirely.

References but no uses: keep a shell, but potentially erase its meaningful contents.

Uses: preserve normally.


The canonical example in the source is ref.func. A function may appear in IR because some expression constructs a reference to it, but unless there is an actual call_ref-style path that can invoke it, the function body may never execute. In that case the function is still needed as an entity, but its implementation is not. That is why the pass can leave the function in place yet smash the body to unreachable. 

This is the first important thing to understand: the pass is not just reachability over syntax. It tries to model semantic reachability: what may actually execute, what merely needs to exist for validation, and what may be read later under Wasm GC / function-reference semantics. 

2. The tracked universe: ModuleElement

Internally, the pass tracks module items as a pair:

ModuleElementKind

Name


So each tracked node is something like:

(Function, foo)

(Global, g0)

(Table, t)

(ElementSegment, elem3)


That is the unit stored in the used and referenced sets and pushed on the module work queue. There is also a separate IndirectCall pair of (table, heapType) used for modeling call_indirect. 

3. The two-phase worklist engine in Analyzer

The real logic lives in the nested Analyzer struct. It maintains:

used: module elements definitely semantically used.

referenced: module elements that must remain valid in the IR.

moduleQueue: used module elements whose internals still need scanning.

expressionQueue: expressions whose children / semantic references still need scanning.

calledSignatures: heap types seen in call_ref-style use.

uncalledRefFuncMap: ref.funcs seen for types that have not yet been called.

readStructFields: struct fields proven to be read somewhere.

unreadStructFieldExprMap: expressions stored into fields that may become relevant if a read is later discovered.

flatTableInfoMap: cached “for this table and heap type, which funcs/segments matter?” info.

lazily computed SubTypes and table mutability metadata. 


The constructor calls prepare(), seeds the roots as used, and then repeatedly drains both queues until reaching a fixed point:

processExpressions()

processModule()


This alternating worklist is the engine of the pass. It is effectively a custom reachability solver with delayed semantic edges. 

4. Noter: the expression scanner

Expression scanning is performed by Noter, a PostWalker that does not directly mutate the module or analysis state. Instead it records findings into vectors:

used

referenced

callRefTypes

refFuncs

structFields

indirectCalls


This separation matters because the same basic syntactic scan is reused in slightly different contexts, especially when the pass wants to add only references rather than uses. 

Generic field-based use handling

visitExpression uses Binaryen’s delegation macros to generically mark named module-element fields as used. So if an instruction directly names a global/table/memory/etc. in a way the IR treats as a syntactic operand, that normally becomes a use. 

Special cases override the generic behavior

Several instructions get custom handling because naive “all named fields are used” is too conservative or wrong:

Call

CallIndirect

CallRef

RefFunc

StructGet

ContNew 


Those special cases are where most of the subtlety lives.

5. Direct calls: visitCall

A normal call marks the target function as used. That part is straightforward. 

But the pass also handles Binaryen intrinsics specially:

call.without.effects

If the intrinsic is a call-without-effects wrapper, the pass treats the passed function reference as actually callable, even though closed-world reasoning might otherwise miss that because the ref is flowing into what looks like an import/intrinsic boundary. If the target operand is a visible ref.func, it synthesizes the equivalent of a direct call. Otherwise it synthesizes the equivalent of a call_ref on the operand’s type. 

configureAll

If the intrinsic is configureAll, the pass marks every function mentioned there as used, with the source comment noting that JS can call them. 

So direct-call handling is already more than “mark target live”; it also patches known holes in closed-world reasoning around intrinsics. 

6. Indirect calls: visitCallIndirect and useIndirectCall

A call_indirect is not treated as “use the whole table.” Instead it does two things:

1. It references the table.


2. It records (table, heapType) for later semantic resolution. 



Later, useIndirectCall resolves that pair. It first deduplicates via usedIndirectCalls, then consults flatTableInfoMap, a precomputed map built in prepare(). That map tells the analyzer, for each table and for each callable heap type, which:

functions may be called through that type, and

element segments contributed those entries. 


For a newly seen indirect-call signature, the pass:

marks all matching table functions as used,

marks all contributing element segments as referenced,

and, if the table may be modified at runtime, also treats the heap type like a call_ref, because future table writes could introduce new functions of that type not present in the initial element segments. For that it lazily computes TableUtils::computeTableInfo and checks mayBeModified. 


That is a very Binaryen-ish semantic optimization: initial table contents are handled precisely, but mutable tables force a more conservative “any function reference of this signature might eventually be called” fallback. 

7. Function references: visitRefFunc, visitCallRef, and closed-world logic

This is one of the most important parts of the pass.

visitCallRef

call_ref does not immediately mark specific functions as used. Instead, if the target expression has a ref type, the pass records the heap type in callRefTypes. If the target is not a ref type, it bails out, treating unreachable/non-callable situations as irrelevant here. 

visitRefFunc

ref.func $f does not automatically mean $f is used.

If the target function is annotated jsCalled, then a reference is treated as strong enough to count as a use.

Otherwise the pass just records the ref.func target for later correlation with call_ref activity. 


useRefFunc

This is where the closed-world assumption matters.

If closedWorld is false, a ref.func is conservatively treated as a use, because the reference could escape and be called somewhere the pass cannot see. 

If closedWorld is true, the pass attempts the stronger optimization:

If that function’s signature type is already in calledSignatures, the function is used.

Otherwise it is only referenced, and the function name is stored in uncalledRefFuncMap[type]. 


useCallRefType

When a callable heap type is later observed, useCallRefType computes SubTypes if needed and then marks all previously seen ref.funcs for that type and its subtypes as used. It then erases those entries from uncalledRefFuncMap and records the subtypes in calledSignatures. 

That means the pass is effectively waiting for the conjunction:

“I saw a ref.func of function f”

and “I saw some call_ref/cont.new/mutable-table-possible call path for that signature”


Only then does f become used. Until then, it is merely referenced. 

This is one of the pass’s main precision wins over a simplistic graph walk.

8. Struct field laziness: reads vs writes in GC structs

The other major precision trick is around GC struct fields.

Reads: visitStructGet

When the pass sees struct.get, if the ref is neither unreachable nor null, it records the pair (heapType, fieldIndex) as a read candidate. 

Writes / construction: scanChildren special-cases struct.new

Normally the analyzer just queues all expression children. But for struct.new in closed world, non-unreachable situations, it does something smarter:

It immediately uses the descriptor child if present.

For each field operand, it decides whether to:

use it now, or

delay it as “unread field payload.” 



It uses the operand immediately if:

that field has already been observed as read,

or the operand has side effects according to EffectAnalyzer,

or the operand contains calls discovered via FindAll, which is a special workaround because call.without.effects can hide meaningful code execution from the side-effect analysis. 


If none of those hold, the operand is not considered truly used yet. Instead:

it is stored in unreadStructFieldExprMap[field],

and addReferences(operand) is run so anything named inside remains valid in the IR even if the field is never read. 


Later, if a field is read: useStructField

When useStructField sees the first read of a field, it expands that read to all subtypes of the struct heap type via SubTypes::iterSubTypes, marks those fields as read, and then promotes any queued unread expressions for those fields into full uses by calling use(expr) on them. Then it erases the deferred entries. 

This is subtle and powerful. It means the pass can avoid keeping alive complex field payloads—like ref.funcs nested in structs—unless some actual read can reach them. That is much more precise than treating struct.new operands as immediately live. 

9. Why addReferences() exists

When a deferred field payload is not used now, the pass still needs the IR to validate if that expression remains in the output. That is why addReferences() exists: it scans an expression and converts all discovered module-element dependencies into references, not uses. 

Notably:

generic used and referenced findings from Noter are both demoted to reference(...),

ref.func targets become only referenced,

and nothing is done for type-only facts like callRefTypes or structFields, because those are not module-element references. 


The source explicitly warns that calling useRefFunc() here would be wrong, because that would accidentally upgrade a mere reference-bearing expression into executable liveness. 

This is a clean separation:

use(...) means “this can semantically execute / matter”

reference(...) means “this must still exist so the remaining IR is valid” 


10. Reference propagation rules

The reference(ModuleElement) method deduplicates work, then handles cases where referencing the outer shell implies references to internals.

Referenced globals

A non-imported global has an initializer expression that remains part of the module if the global remains. Since the pass does not know how to “empty out” globals the way it can empty functions, it recursively adds references from the initializer. The source explicitly notes that globals are harder than functions here and leaves better handling as a TODO. 

Referenced element segments

If an element segment must remain, the pass adds references from every segment item expression, again so the surviving IR stays valid. The source notes another TODO: it could potentially do finer-grained shrinking of element segments later. 

There is no analogous shell-rewrite optimization for globals or segments today. The special “replace body with unreachable” trick is basically only used for functions. 

11. processModule(): how used module elements expand

When a module element is marked used, the analyzer may need to inspect the things it can reach:

Function: if defined, use its body.

Global: if defined, use its initializer.

Tag: nothing else to inspect.

Memory: any non-empty segments associated with it become used.

Table: any non-empty element segments associated with it become used.

DataSegment: if active, use offset expression and the target memory.

ElementSegment: if active, use offset expression, target table, and each item expression. 


This is the module-level analogue of traversing expression children. It is the mechanism by which roots fan out into the rest of the module graph. 

12. prepare(): precomputing indirect-call table info

Before the analysis starts, Analyzer::prepare() scans element segments with tables and constructs flatTableInfoMap.

For each ref.func item in a segment, it looks up the function’s heap type and inserts that function name and segment name into maps for:

the exact function type, and

every supertype reachable via getSuperType(). 


This is crucial because a call_indirect on a supertype may target functions whose exact types are subtypes. By pre-flattening “type plus all subtype contributions” into one lookup table, useIndirectCall() becomes cheap and precise at runtime. 

13. Root selection in run()

The top-level pass creates an initial roots vector before constructing the analyzer.

Start function

If the module has a start function, it is normally rooted. But there is a neat micro-optimization: if the start function is defined and has an empty body (body->is()), Binaryen simply removes the module start instead of rooting it. 

Optional “root all functions”

The pass instance carries rootAllFunctions. If true, all defined functions are rooted up front. Binaryen exposes this as createRemoveUnusedNonFunctionModuleElementsPass(). That variant removes unused non-function elements but keeps all functions alive. 

Exports

All exported internal items of kinds function/global/tag/table/memory are rooted. So the normal pass will never remove an exported item merely because nothing inside the module uses it. 

That is why external export-pruning is handled by wasm-metadce, not by this pass alone. wasm-metadce can remove exports based on an outside-supplied reachability graph, then invoke remove-unused-module-elements afterward to clean up the now-internal dead items. The tool source says exactly that. 

Active segments that write to imported state

Active data/element segments are rooted if:

they write non-empty data into an imported memory/table, because that write is externally observable,

or they may trap at instantiation time. 


The helper maybeRootSegment checks trap possibility unless trapsNeverHappen is enabled. A segment may trap if the offset is not a constant, if address addition overflows, or if the computed end exceeds the parent’s initial bounds. 

Maybe-trapping constant initializers

If trapsNeverHappen is false, the pass also roots:

element segments whose initializer expressions may trap due to nullable struct.new descriptors,

globals whose initializer expressions may trap for the same reason. 


This comes from isMaybeTrappingInit(), which walks the initializer and flags any struct.new with a nullable descriptor type. The source notes that this is the modeled trap source for constant expressions, aside from implementation-limit issues. 

So rooting is not just about externally callable entry points; it also preserves externally observable instantiation behavior, including startup writes and startup traps. 

14. Removal phase: what actually gets deleted

After analysis, the pass defines needed(element) as:

in used, or

in referenced. 


Then it removes module items kind by kind.

Functions

For each function:

if used: keep as-is.

else if referenced: keep it, but if defined replace its body with unreachable.

else: remove it entirely. 


This replacement preserves references and validation while dropping the function’s executable contents. It also avoids needing local fixups; the pass explicitly overrides requiresNonNullableLocalFixups() to false, noting that replacing the whole body with unreachable does not create the usual local-type repair issues. 

Globals, tags, memories, tables, data segments, element segments

These are simply removed if not needed. There is no intermediate shell state analogous to function-body replacement, except for the implicit reference propagation work done earlier to keep referenced survivors valid. 

The source also notes a future improvement opportunity: after removing some elements, more things may become removable, but the pass does not iterate again today. 

15. The disabled prepare(Module*) optimization

There is a second top-level prepare(Module*) method on the pass itself. Its intent is to rewrite certain trivial exported trampolines:

if an exported function body is just a direct forwarding call with identical type and pure parameter forwarding,

then Binaryen could retarget the export to the real callee,

potentially making the trampoline dead. 


However, this optimization is currently disabled: the function immediately returns, with a comment saying it was disabled because it uncovered bugs in both LLVM and Binaryen, pointing to PR discussion #6026. So in current main, this pre-optimization does nothing. 

That is worth calling out because someone reading the file casually might think trampoline-export collapsing is part of current behavior. It is not, at least as of the present source. 

16. Relationship to wasm-metadce

RemoveUnusedModuleElements is intentionally limited by its root model: exports are roots, because inside a standalone module Binaryen cannot know which exports the outside world truly needs. The wasm-metadce tool exists to solve that larger problem using an external graph. It removes unused exports first, then invokes remove-unused-module-elements, and the tool source explicitly says this pass has detailed Wasm-semantic knowledge that can remove even more than the graph alone found. 

So a good mental model is:

wasm-metadce = inter-module / embedding-aware export pruning

RemoveUnusedModuleElements = intra-module semantic DCE cleanup once roots are known 


17. What makes this pass unusually sophisticated

Several things make this pass more than ordinary mark-and-sweep:

1. It distinguishes reference validity from actual execution/use. 


2. It models function references using the conjunction of ref.func plus call_ref-reachable signature use. 


3. It models indirect calls by table + heap type, not by “whole table is live.” 


4. It models mutable tables conservatively via mayBeModified. 


5. It models struct field liveness lazily, delaying field payload liveness until there is evidence of a read. 


6. It preserves startup side effects and startup traps as roots. 


7. It has a dedicated “referenced but not used” lowering for functions by rewriting bodies to unreachable. 



In other words, the pass is best understood as a semantic liveness analysis for module entities, not just a graph walk over named references.

18. Practical implications for someone reimplementing it

If you were re-creating this pass, the irreducible design ideas are:

Maintain two lattices, not one: referenced and used.

Make roots include both entry points and startup observability.

Delay liveness for ref-typed and GC-typed payloads until you see an actual semantic consumer.

Precompute table/type relationships for efficient call_indirect resolution.

In closed world, let ref.func be weak until matched with callable type evidence.

Preserve IR validity for deferred expressions by separately collecting references.

Support a shell state for entities that must remain indexable/nameable but need not remain executable. 


19. The shortest accurate summary

RemoveUnusedModuleElements starts from roots such as exports, the start function, observable/trapping active initializers, and optionally all functions. It then performs a fixed-point analysis that distinguishes module elements that must exist from those that may actually execute or be read. It handles function references, indirect calls, table mutation, and GC struct fields with special semantic logic. At the end, it deletes anything neither referenced nor used, and for functions that are referenced but not used, it preserves the declaration but replaces the body with unreachable. 

If you want, I can turn this into a second pass over the code in “annotated pseudocode” form, function by function.

Absolutely. Here is a function-by-function annotated pseudocode pass over Binaryen’s RemoveUnusedModuleElements.cpp, with the emphasis on what each routine is trying to prove, why the bookkeeping exists, and how the fixed-point evolves. The pass is described by Binaryen as “Global DCE,” and the source file itself frames the core idea as a three-state model: no references, references-but-no-use, and actual use. 

Big picture pseudocode

The pass is easiest to understand as this pipeline:

run(module):
  prepare(module)        // currently returns immediately; old trampoline tweak disabled

  roots = computeRoots(module)

  analyzer = Analyzer(module, passOptions, roots)
    analyzer.prepare()   // precompute table/type facts
    mark all roots as used
    repeat until fixed point:
      processExpressions()
      processModule()

  remove everything not needed
    if function is referenced but not used:
      keep symbol, replace body with unreachable

That is the whole pass skeleton. The sophistication is in how Analyzer distinguishes reference validity from semantic liveness, especially for ref.func, call_ref, call_indirect, and GC struct fields. 


---

File header comments: the semantic contract

Before any code, the file states the key invariant:

state of an element:
  1. no references    -> remove entirely
  2. references only  -> keep something, but contents may be discardable
  3. used             -> keep intact

The motivating example is ref.func without a matching callable path. The function entity must still exist so the reference stays valid, but the function body may be replaced with unreachable. That design decision explains most of the rest of the pass. 


---

Part 1: the lightweight scanner, Noter

Type aliases

ModuleElementKind = ModuleItemKind
ModuleElement = (kind, name)
IndirectCall = (tableName, heapType)

The pass tracks liveness at module-item granularity: function/global/tag/memory/table/data segment/element segment, plus a separate key for indirect-call facts. 

struct Noter

Think of Noter as a non-committal expression scanner. It does not mutate global analysis state directly. It just walks an expression and records findings into buckets:

used:         module elements directly used
referenced:   module elements only referenced
callRefTypes: heap types seen in call_ref-like use
refFuncs:     function names appearing in ref.func
structFields: (heapType, fieldIndex) pairs read by struct.get
indirectCalls:(table, heapType) pairs seen in call_indirect

That separation is deliberate because the same scan results can later be interpreted in two different ways:

“this expression is semantically used”

“this expression only needs its references preserved for validity”


That is why Noter exists instead of folding all logic directly into Analyzer. 

use, reference, noteCallRef, noteRefFunc, noteStructField, noteIndirectCall

These are just append operations:

use(element)           -> used.push_back(element)
reference(element)     -> referenced.push_back(element)
noteCallRef(type)      -> callRefTypes.push_back(type)
noteRefFunc(func)      -> refFuncs.push_back(func)
noteStructField(field) -> structFields.push_back(field)
noteIndirectCall(t, h) -> indirectCalls.push_back((t, h))

No semantics yet; only collection. 

visitExpression(Expression* curr)

This is the generic fallback scanner.

Pseudocode:

visitExpression(curr):
  for each named module-element field in curr:
    if field has a name:
      mark it as used

Binaryen implements this with delegation macros over IR fields. The important point is the default behavior is optimistic toward use: if an instruction directly names a memory/table/global/function/etc., Noter assumes that counts as a use unless a more specific visitor overrides it. 

That is why special instructions need custom handling.


---

Part 2: Noter special visitors

visitCall(Call* curr)

Pseudocode:

visitCall(call):
  use(Function, call.target)

  if call is intrinsic call.without.effects:
    target = last operand
    if target is ref.func f:
      synthesize a direct call to f
    else:
      synthesize a call_ref on target.type

  else if call is intrinsic configureAll:
    for each configured function f:
      use(Function, f)

Why this matters

The direct-call part is obvious. The intrinsic handling is not.

call.without.effects is tricky because it hides effects for optimization purposes, but it is still a real call path semantically. If the pass ignored that, it could conclude a function reference is never callable and incorrectly erase its body. So this visitor turns that intrinsic back into either:

a direct call, if the target is visibly ref.func, or

a signature-level call_ref fact otherwise. 


configureAll is even more conservative: functions mentioned there are treated as callable from JS and therefore used. 

visitCallIndirect(CallIndirect* curr)

Pseudocode:

visitCallIndirect(ci):
  reference(Table, ci.table)
  noteIndirectCall(ci.table, ci.heapType)

This is one of the most important precision choices in the pass. A call_indirect does not make the whole table used. It only proves:

the table must still exist,

some subset of table contents matching the heap type may matter.


The actual resolution is deferred to Analyzer::useIndirectCall. 

visitCallRef(CallRef* curr)

Pseudocode:

visitCallRef(cr):
  if cr.target is not a ref type:
    return   // ignore unreachable / non-callable cases
  noteCallRef(cr.target.heapType)

Again, it does not directly mark any function used. It records only the callable signature type. Actual functions become used later when matched against prior or future ref.funcs of compatible type. 

visitRefFunc(RefFunc* curr)

Pseudocode:

visitRefFunc(rf):
  if function has jsCalled annotation:
    use(Function, rf.func)
  else:
    noteRefFunc(rf.func)

This is the other half of the ref.func / call_ref handshake. A bare ref.func is treated as a potential callable identity, not automatically as live executable code, unless the function is annotated jsCalled, in which case the reference itself is considered as strong as use. 

visitStructGet(StructGet* curr)

Pseudocode:

visitStructGet(get):
  if get.ref is unreachable or null:
    return
  noteStructField((get.ref.heapType, get.index))

This records reads of struct fields. The pass later uses those reads to decide whether data previously stored into that field should count as actually used. 

visitContNew(ContNew* curr)

Pseudocode:

visitContNew(cont):
  if cont.func is not a ref type:
    return
  noteCallRef(cont.func.heapType)

cont.new is treated like a deferred call_ref: a function reference placed there may be called later, so its signature is marked as callable. 


---

Part 3: Analyzer state

Analyzer owns the fixed-point. Its state is the real pass.

Core sets and queues

used

used = set of module elements semantically used

If an element enters this set, it is queued for module-level expansion. 

referenced

referenced = set of module elements that must still exist for IR validity

An element may be in both used and referenced, but used dominates. This is intentional; the pass does not bother removing an element from referenced after it later becomes used. 

moduleQueue

moduleQueue = used module elements whose internals we still need to inspect

Examples:

used function -> inspect body

used data segment -> inspect offset and memory

used element segment -> inspect offset, table, data items 


expressionQueue

expressionQueue = used expressions still waiting to be scanned

The pass does not recurse with the normal walker because it sometimes wants to defer child use, especially for struct.new field operands. 


---

Ref-function bookkeeping

calledSignatures

calledSignatures = set of heap types known to be callable via call_ref-like use

If a function reference of one of these types appears, it is enough to make the function used. 

uncalledRefFuncMap

uncalledRefFuncMap[type] = set of functions seen in ref.func for that type,
                           but not yet proven callable

This is the reverse side of calledSignatures. A function becomes live through references only when both facts exist:

a ref.func of that function,

a call_ref-style use of a compatible type.


Either one may appear first, so the pass stores pending ref.funcs here until a matching call type shows up. 


---

Struct-field bookkeeping

readStructFields

readStructFields = set of (heapType, fieldIndex) known to be read

unreadStructFieldExprMap

unreadStructFieldExprMap[field] = expressions previously stored into field,
                                  but not yet considered used

This mirrors the ref.func logic almost exactly. For a stored expression to count as truly used, the pass wants both:

a write of that expression into the field,

some observed read of that field.


Until then, the field payload may be only referenced, not used. 


---

Table cache

FlatTableInfo

FlatTableInfo:
  typeFuncs[type] = functions in table callable as that type
  typeElems[type] = element segments supplying those functions

This is a preflattened map for indirect-call reasoning. It already accounts for subtyping by inserting each function under its exact heap type and all supertypes. 

flatTableInfoMap

flatTableInfoMap[tableName] = FlatTableInfo for that table

This makes call_indirect(table, type) resolution fast later. 


---

Part 4: Analyzer constructor and preparation

Analyzer(module, options, roots)

Pseudocode:

Analyzer(module, options, roots):
  this.module = module
  this.options = options

  prepare()

  for root in roots:
    use(root)

  while processExpressions() or processModule():
    continue

That final loop is the whole fixed-point engine. It keeps alternating between:

expression-driven discovery

module-element-driven discovery


until neither queue adds anything new. 

prepare()

Pseudocode:

prepare():
  for each element segment elem with a table:
    for each item in elem.data:
      if item is ref.func f:
        type = heap type of f
        while type exists:
          flatTableInfo[elem.table].typeFuncs[type].add(f)
          flatTableInfo[elem.table].typeElems[type].add(elem.name)
          type = supertype(type)

This routine precomputes the initial contents of each table as a type-indexed reachability map. If a function has exact type Tsub, then an indirect call through Tsub or any supertype of Tsub may reach it, so the function and its segment are indexed under all of those. 


---

Part 5: processing used expressions

processExpressions()

Pseudocode:

processExpressions():
  worked = false
  while expressionQueue not empty:
    worked = true
    curr = pop(expressionQueue)

    noter = scan curr with Noter

    for each module element in noter.used:
      use(element)

    for each module element in noter.referenced:
      reference(element)

    for each heap type in noter.callRefTypes:
      useCallRefType(type)

    for each function name in noter.refFuncs:
      useRefFunc(func)

    for each struct field in noter.structFields:
      useStructField(field)

    for each indirect call fact in noter.indirectCalls:
      useIndirectCall(call)

    scanChildren(curr)

  return worked

This is the heart of the expression-side solver. It first extracts facts from the current expression, then hands each fact to the semantic routines that know how to upgrade references into uses or defer them. Only after that does it decide how to traverse children. 

The order matters. For example, the pass wants struct.new special handling in scanChildren, not generic recursive traversal first. 


---

Part 6: signature-driven function activation

useCallRefType(HeapType type)

Pseudocode:

useCallRefType(type):
  if type is basic/bottom:
    return

  ensure subTypes table exists

  for each subType in subTypes(type):
    if uncalledRefFuncMap contains subType:
      for each function f in uncalledRefFuncMap[subType]:
        use(Function, f)
      erase uncalledRefFuncMap[subType]

    calledSignatures.add(subType)

This routine means: “some expression can call a function reference of this type.” Therefore every previously seen ref.func of that type or any subtype now becomes executable and must be marked used. Then the type is remembered in calledSignatures so future ref.funcs of that signature can be marked used immediately. 

A subtle point: it iterates over subtypes, not supertypes. That matches Wasm’s function reference semantics: a call through type T can target functions whose exact types are subtypes of T. 


---

Part 7: indirect-call activation

usedIndirectCalls

usedIndirectCalls = dedup set of (table, heapType)

Needed so the same indirect-call pattern is not re-expanded repeatedly. 

tableInfoMap

tableInfoMap = lazily computed TableUtils::computeTableInfo(*module)

Used only to ask whether a table may be mutated at runtime. 

useIndirectCall(IndirectCall call)

Pseudocode:

useIndirectCall((table, type)):
  if already processed:
    return

  for each function f in flatTableInfoMap[table].typeFuncs[type]:
    use(Function, f)

  for each element segment e in flatTableInfoMap[table].typeElems[type]:
    reference(ElementSegment, e)

  ensure tableInfoMap exists
  if table may be modified:
    useCallRefType(type)

This routine has three layers:

1. Initial table contents: functions already placed in the table with compatible type become used.


2. Their origin segments: those element segments must remain valid, so they are referenced.


3. Future mutations: if the table can change at runtime, the initial element segments are not the whole story. Any function reference of that heap type may eventually be written into the table, so the pass conservatively upgrades the type to a call_ref-style callable signature via useCallRefType(type). 



That last step is why mutable tables weaken precision. 


---

Part 8: ref.func semantics

useRefFunc(Name func)

Pseudocode:

useRefFunc(func):
  if not closedWorld:
    use(Function, func)
    return

  element = (Function, func)
  type = func.heapType

  if type in calledSignatures:
    use(element)
  else:
    uncalledRefFuncMap[type].add(func)
    reference(element)

This is the pass’s most important “weak liveness” rule.

In an open world, Binaryen cannot assume the function reference stays internal, so a ref.func is conservatively treated as enough to make the function used. In a closed world, Binaryen can do better: until a matching call_ref-style use exists, the function is only referenced, not used. 

That is exactly what enables the later “keep symbol, body = unreachable” optimization. 


---

Part 9: struct field activation

useStructField(StructField field)

Pseudocode:

useStructField((type, index)):
  if field already marked read:
    return

  ensure subTypes table exists

  for each subtype S of type:
    subField = (S, index)
    readStructFields.add(subField)

    if unreadStructFieldExprMap contains subField:
      for each expr in unreadStructFieldExprMap[subField]:
        use(expr)
      erase unreadStructFieldExprMap[subField]

Meaning: once the pass has seen that field index is read on heap type type, then payloads previously written into that field on type or its subtypes become truly used and must now be traversed fully. 

Again, subtype expansion is essential: a read through a supertype may land on a subtype instance. 


---

Part 10: processing used module elements

processModule()

Pseudocode:

processModule():
  worked = false
  while moduleQueue not empty:
    worked = true
    curr = pop(moduleQueue)

    switch curr.kind:
      Function:
        if defined:
          use(func.body)

      Global:
        if defined:
          use(global.init)

      Tag:
        nothing more

      Memory:
        for each non-empty data segment on this memory:
          use(DataSegment, segment)

      Table:
        for each non-empty element segment on this table:
          use(ElementSegment, segment)

      DataSegment:
        if active:
          use(segment.offset)
          use(Memory, segment.memory)

      ElementSegment:
        if active:
          use(segment.offset)
          use(Table, segment.table)
        for each item expr in segment.data:
          use(expr)

  return worked

This is the module-level expansion step. It converts a used module item into the expressions and other module items it depends on. 

A useful mental model: processExpressions() reasons about instruction semantics, while processModule() reasons about container semantics. 


---

Part 11: the primitive enqueue operations

use(ModuleElement element)

Pseudocode:

use(element):
  if element newly inserted into used:
    moduleQueue.push(element)

This is the only path for module elements to become semantically live. Deduplication happens here. 

use(Expression* curr)

Pseudocode:

use(expr):
  expressionQueue.push(expr)

No dedup set is needed because Binaryen expressions form a tree, not a DAG with shared nodes. The pass relies on tree ownership to avoid revisiting children through multiple parents. 


---

Part 12: child traversal and lazy struct.new

scanChildren(Expression* curr)

This routine is where the pass refuses to naively recurse into struct.new field operands.

Fast path

Pseudocode:

if not closedWorld
   or curr is unreachable
   or curr is not StructNew:
  for child in children(curr):
    use(child)
  return

So the optimization only applies in closed-world, type-known, struct.new cases. 

Special struct.new handling

Pseudocode:

new_ = cast<StructNew>(curr)

if new_.desc exists:
  use(new_.desc)

type = new_.type.heapType

for each operand i:
  operand = new_.operands[i]
  field = (type, i)

  useOperandNow = field already read

  if not useOperandNow:
    useOperandNow = operand has side effects

  if not useOperandNow:
    useOperandNow = operand contains any Call
      // catches call.without.effects cases

  if useOperandNow:
    use(operand)
  else:
    unreadStructFieldExprMap[field].push_back(operand)
    addReferences(operand)

Why descriptor is treated differently

The descriptor child is used immediately because the pass’s “lazy field payload” optimization already operates one level down on the descriptor struct itself; it does not need another special case. The source comments walk through an example with nested struct.new descriptors containing ref.funcs. 

Why side effects force immediate use

If a field initializer has side effects, those effects happen whether or not the field is ever read later, so the pass cannot defer it. It must count as used immediately. 

Why FindAll<Call> exists

EffectAnalyzer deliberately treats call.without.effects as effect-free for optimization, but RemoveUnusedModuleElements still needs to know that code behind it may be semantically reached. So after the side-effect test, the pass separately looks for any Call nodes as a backstop. 


---

Part 13: preserving validity without upgrading to use

addReferences(Expression* curr)

Pseudocode:

addReferences(expr):
  noter = walk expr with Noter

  for element in noter.used:
    reference(element)

  for element in noter.referenced:
    reference(element)

  for func in noter.refFuncs:
    reference(Function, func)

  ignore noter.callRefTypes and noter.structFields

This routine is one of the most conceptually important in the file.

It says: “this expression will remain in the output, but I am not yet willing to say it is semantically used.” Therefore, collect every module element it mentions and keep those entities alive as references only. 

The source explicitly warns not to call useRefFunc() here. Doing so would turn a merely preserved ref.func into an executable-liveness fact, which would be wrong. 

Ignoring callRefTypes and structFields is also deliberate: those are type facts, not module-element references. 


---

Part 14: recursive reference propagation

reference(ModuleElement element)

Pseudocode:

reference(element):
  if element already in referenced:
    return

  referenced.add(element)

  switch element.kind:
    Global:
      if defined:
        addReferences(global.init)

    ElementSegment:
      for each item in segment.data:
        addReferences(item)

    otherwise:
      nothing extra

The idea is: some items, merely by surviving in the output, force their contents to remain valid too.

Globals

Binaryen does not currently have a simple “empty out a global” analogue to function-body replacement, so a referenced global must keep a valid initializer. Therefore the pass recursively preserves references in the initializer. The source notes this as an area for possible future improvement. 

Element segments

Likewise, a referenced element segment must keep valid item expressions, so their references are recursively preserved. The file notes that finer-grained shrinking might be possible later. 

The dedup check at the top is not just cleanup; the source comments point out it prevents exponential blowups through repeated global-reference chains. 


---

Part 15: top-level pass object

requiresNonNullableLocalFixups()

Pseudocode:

requiresNonNullableLocalFixups() -> false

The pass claims it does not need non-nullable local fixups because its only function-body rewrite is replacing the entire body with unreachable, which always validates and does not create partial local-typing inconsistencies. 

RemoveUnusedModuleElements(bool rootAllFunctions)

Just stores the configuration flag. Binaryen exposes both normal mode and a variant that roots all functions. 


---

Part 16: root discovery in run(Module* module)

run(Module* module)

This is the top-level orchestration.

Step 1: prepare(module)

Called first, but currently it returns immediately because an old optimization is disabled. More on that below. 

Step 2: initialize roots

Start function

Pseudocode:

if module.start exists:
  if start is defined and body is Nop:
    clear module.start
  else:
    root(Function, module.start)

So an empty start function is simply removed as start rather than rooted. 

Optional root-all-functions mode

Pseudocode:

if rootAllFunctions:
  for each defined function:
    root(Function, func.name)

This is the behavior behind createRemoveUnusedNonFunctionModuleElementsPass(): remove dead non-function items while preserving all defined functions. 

Exports

Pseudocode:

for each export:
  root its internal function/global/tag/table/memory

Exports are always roots in this pass. That is why Binaryen needs wasm-metadce for export-level whole-program DCE; RemoveUnusedModuleElements itself will not remove exports just because nothing internal uses them. 


---

Step 3: root active segments with observable startup effects

The helper lambda is conceptually:

maybeRootSegment(kind, segmentName, segmentSize, offset, parent, parentSize):
  writesToVisible = parent is imported and segmentSize > 0
  mayTrap = false

  if not trapsNeverHappen:
    if offset is not a constant
       or segmentSize + offset overflows
       or segment end > parentSize:
      mayTrap = true

  if writesToVisible or mayTrap:
    root(kind, segmentName)

This means active segments are rooted if they either:

write into imported memory/table, which is externally visible, or

may trap during instantiation, which is also externally observable. 


Then run() applies that helper to active data segments and active element segments. 


---

Step 4: root maybe-trapping constant initializers

Pseudocode:

if not trapsNeverHappen:
  for each element segment init expr:
    if isMaybeTrappingInit(init):
      root(ElementSegment, segment)

  for each global init expr:
    if isMaybeTrappingInit(init):
      root(Global, global)

This preserves instantiation-time traps from constant expressions, especially nullable descriptors passed to struct.new. 


---

Step 5: analyze

analyzer = Analyzer(module, options, roots)

At this point the fixed-point described earlier runs to completion. 


---

Step 6: remove unneeded elements

Helper:

needed(element) = element in analyzer.used or analyzer.referenced

Then removal proceeds by kind.

Functions

Pseudocode:

removeFunctions(curr):
  if curr is used:
    keep

  else if curr is referenced:
    if defined:
      curr.body = unreachable
    keep

  else:
    remove entirely

This is the most distinctive transformation in the pass. It preserves symbol identity for surviving references while discarding executable contents. 

Globals, tags, memories, tables, data segments, element segments

Pseudocode:

remove if not needed

No analogous “shell rewrite” exists here, except for the earlier recursive reference-preservation logic. The file notes a TODO that a second iteration could potentially remove more after the first wave of deletions, but it does not currently do that. 


---

Part 17: currently disabled pre-optimization

prepare(Module* module)

Right now the function immediately does:

return;

because a previous optimization was disabled after exposing bugs in LLVM and Binaryen. The source comment points to PR discussion for that. 

If it were active, it would retarget exports that point to trivial forwarding trampolines:

(export "x" (func middle))
(func middle (call real (local.get 0) ...))

=> retarget export to real if:
   - body is a plain direct call
   - callee type == wrapper type
   - all parameters are forwarded unchanged

The idea is to make the middle trampoline become dead afterward. But again, this path is disabled in current main. 


---

Part 18: trapping-initializer helper

isMaybeTrappingInit(Module& wasm, Expression* root)

Pseudocode:

isMaybeTrappingInit(root):
  mayTrap = false

  walk root:
    if any struct.new has a descriptor whose type is nullable:
      mayTrap = true

  return mayTrap

The comment explains that nullable descriptors are the modeled source of constant-expression traps here, aside from implementation-limit issues that Binaryen does not try to model. 


---

Part 19: factory functions

createRemoveUnusedModuleElementsPass()

return new RemoveUnusedModuleElements(false)

Normal mode. 

createRemoveUnusedNonFunctionModuleElementsPass()

return new RemoveUnusedModuleElements(true)

Variant that roots all functions and only removes dead non-function module elements. 


---

A compact mental model of the fixed point

If you want the shortest “how it really works” pseudocode, it is this:

roots -> used/moduleQueue

while work remains:
  pop used expressions
    syntactically note:
      direct uses
      references
      callable signature facts
      ref.func facts
      struct field read facts
      call_indirect facts
    semantically upgrade those facts:
      useCallRefType
      useRefFunc
      useStructField
      useIndirectCall
    recurse into children
      except defer pure unread struct field payloads

  pop used module elements
    expand their bodies / initializers / segments / offsets / target tables/memories

And then:

if neither used nor referenced -> delete
if referenced only and function -> keep symbol, body = unreachable
if used -> keep intact

That is the pass in one screen. 


---

The three most important ideas to carry forward

First, reference is not use. That is the pass’s central design decision, and it is what lets Binaryen preserve IR validity without over-retaining executable code. 

Second, function-reference liveness is two-sided: ref.func alone is weak, call_ref alone is only a type fact, and the function becomes used when those meet, plus similar logic through indirect calls and mutable tables. 

Third, GC struct payloads are also two-sided: writing a payload into a field does not necessarily make it used until the field is proven readable somewhere. That symmetry with the ref.func logic is one of the nicest aspects of the implementation. 

If you want, I can do one more pass and turn this into a state-transition diagram for used, referenced, uncalledRefFuncMap, calledSignatures, and unreadStructFieldExprMap.