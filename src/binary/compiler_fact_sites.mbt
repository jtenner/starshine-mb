///|
fn[T : Encode] compiler_fact_encoded_length(
  value : T,
) -> Result[Int, BinaryEncodeError] {
  let buf = @buffer.new()
  match Encode::encode(value, buf) {
    Ok(_) => Ok(buf.to_bytes().length())
    Err(err) => Err(err)
  }
}

///|
fn compiler_fact_collect_opcode_offsets(
  instructions : Array[Instruction],
  offsets : Array[UInt],
  cursor : Ref[Int],
) -> Result[Unit, BinaryEncodeError] {
  for instruction in instructions {
    offsets.push(cursor.val.reinterpret_as_uint())
    match instruction {
      Block(block_type, Expr(body)) => {
        let encoded = match
          compiler_fact_encoded_length(
            Instruction::block(block_type, Expr::new([])),
          ) {
          Ok(length) => length
          Err(err) => return Err(err)
        }
        cursor.val += encoded - 1
        if compiler_fact_collect_opcode_offsets(body, offsets, cursor)
          is Err(err) {
          return Err(err)
        }
        cursor.val += 1
      }
      Loop(block_type, Expr(body)) => {
        let encoded = match
          compiler_fact_encoded_length(
            Instruction::loop_(block_type, Expr::new([])),
          ) {
          Ok(length) => length
          Err(err) => return Err(err)
        }
        cursor.val += encoded - 1
        if compiler_fact_collect_opcode_offsets(body, offsets, cursor)
          is Err(err) {
          return Err(err)
        }
        cursor.val += 1
      }
      If(block_type, then_body, else_body) => {
        let encoded = match
          compiler_fact_encoded_length(Instruction::if_(block_type, [], None)) {
          Ok(length) => length
          Err(err) => return Err(err)
        }
        cursor.val += encoded - 1
        if compiler_fact_collect_opcode_offsets(then_body, offsets, cursor)
          is Err(err) {
          return Err(err)
        }
        match else_body {
          Some(body) => {
            cursor.val += 1
            if compiler_fact_collect_opcode_offsets(body, offsets, cursor)
              is Err(err) {
              return Err(err)
            }
          }
          None => ()
        }
        cursor.val += 1
      }
      Try(block_type, Expr(body), catches, delegate) => {
        if (catches.is_empty() && delegate is None) ||
          (!catches.is_empty() && delegate is Some(_)) {
          return Err(BinaryEncodeError::InvalidLegacyTryShape)
        }
        let encoded = match
          compiler_fact_encoded_length(
            Instruction::block(block_type, Expr::new([])),
          ) {
          Ok(length) => length
          Err(err) => return Err(err)
        }
        cursor.val += encoded - 1
        if compiler_fact_collect_opcode_offsets(body, offsets, cursor)
          is Err(err) {
          return Err(err)
        }
        match delegate {
          Some(label) => {
            cursor.val += 1
            let label_length = match compiler_fact_encoded_length(label) {
              Ok(length) => length
              Err(err) => return Err(err)
            }
            cursor.val += label_length
          }
          None => {
            for catch_ in catches {
              match catch_ {
                @lib.LegacyCatch(tag, Expr(catch_body)) => {
                  cursor.val += 1
                  let tag_length = match compiler_fact_encoded_length(tag) {
                    Ok(length) => length
                    Err(err) => return Err(err)
                  }
                  cursor.val += tag_length
                  if compiler_fact_collect_opcode_offsets(
                      catch_body, offsets, cursor,
                    )
                    is Err(err) {
                    return Err(err)
                  }
                }
                @lib.LegacyCatchAll(Expr(catch_body)) => {
                  cursor.val += 1
                  if compiler_fact_collect_opcode_offsets(
                      catch_body, offsets, cursor,
                    )
                    is Err(err) {
                    return Err(err)
                  }
                }
              }
            }
            cursor.val += 1
          }
        }
      }
      TryTable(block_type, catches, Expr(body)) => {
        let encoded = match
          compiler_fact_encoded_length(
            Instruction::try_table(block_type, catches, Expr::new([])),
          ) {
          Ok(length) => length
          Err(err) => return Err(err)
        }
        cursor.val += encoded - 1
        if compiler_fact_collect_opcode_offsets(body, offsets, cursor)
          is Err(err) {
          return Err(err)
        }
        cursor.val += 1
      }
      _ => {
        let encoded = match compiler_fact_encoded_length(instruction) {
          Ok(length) => length
          Err(err) => return Err(err)
        }
        cursor.val += encoded
      }
    }
  }
  Ok(())
}

///|
/// Return the canonical encoded byte offsets of every instruction opcode in an
/// expression. Structural delimiter bytes such as `else`, `catch`, and `end`
/// are not instruction sites.
pub fn compiler_fact_opcode_offsets(
  expression : Expr,
  stringrefs? : Array[Bytes]? = None,
) -> Result[Array[UInt], BinaryEncodeError] {
  with_binary_encode_stringrefs_context(stringrefs, fn() {
    let Expr(instructions) = expression
    let offsets : Array[UInt] = []
    let cursor = Ref::new(0)
    match compiler_fact_collect_opcode_offsets(instructions, offsets, cursor) {
      Ok(_) => Ok(offsets)
      Err(err) => Err(err)
    }
  })
}

///|
/// Return canonical instruction-opcode offsets for every defined function body
/// using the same synthesized string-reference pool as module encoding.
pub fn compiler_fact_module_opcode_offsets(
  module_ : Module,
) -> Result[Array[Array[UInt]], BinaryEncodeError] {
  let stringrefs = encode_module_stringrefs(module_)
  let context = if stringrefs.is_empty() { None } else { Some(stringrefs) }
  with_binary_encode_stringrefs_context(context, fn() {
    let functions = match module_.code_sec {
      Some(CodeSec(functions)) => functions
      None => []
    }
    let indexed : Array[Array[UInt]] = []
    for function in functions {
      let Func(_, Expr(instructions)) = function
      let offsets : Array[UInt] = []
      let cursor = Ref::new(0)
      match
        compiler_fact_collect_opcode_offsets(instructions, offsets, cursor) {
        Ok(_) => indexed.push(offsets)
        Err(err) => return Err(err)
      }
    }
    Ok(indexed)
  })
}
