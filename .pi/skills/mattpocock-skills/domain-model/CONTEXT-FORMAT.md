# CONTEXT.md Format

## Suggested structure
```md
# {Context Name}

{1-2 sentence summary}

## Language
**Order**:
A customer's request to purchase one or more items.
_Avoid_: Purchase, transaction

## Relationships
- An **Order** produces one or more **Invoices**

## Example dialogue
> **Dev:** "When does an **Invoice** get created?"
> **Expert:** "Only after fulfillment is confirmed."

## Flagged ambiguities
- "account" was used for both **Customer** and **User** — resolved as distinct.
```

## Rules
- be opinionated about terms
- keep definitions tight
- show relationships
- record ambiguities explicitly
- only include project-specific language
