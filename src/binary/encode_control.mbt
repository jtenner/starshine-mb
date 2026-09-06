///|
// Sequence cursors retain O(depth) work, including for wide instruction lists.
priv enum ControlEncodeWork {
  ControlInstruction(Instruction)
  ControlSequence(Array[Instruction], Int)
  ControlCatches(Array[@lib.LegacyCatch], Int)
  ControlDelegate(@lib.LabelIdx)
  ControlByte(Byte)
}

///|
fn encode_control_work(
  work : Array[ControlEncodeWork],
  buf : @buffer.Buffer,
) -> Result[Unit, BinaryEncodeError] {
  while work.pop() is Some(task) {
    match task {
      ControlByte(value) => buf.write_byte(value)
      ControlDelegate(label) => {
        buf.write_byte(0x18)
        if Encode::encode(label, buf) is Err(err) {
          return Err(err)
        }
      }
      ControlSequence(values, index) =>
        if index < values.length() {
          if index + 1 < values.length() {
            work.push(ControlSequence(values, index + 1))
          }
          work.push(ControlInstruction(values[index]))
        }
      ControlCatches(values, index) =>
        if index < values.length() {
          if index + 1 < values.length() {
            work.push(ControlCatches(values, index + 1))
          }
          match values[index] {
            @lib.LegacyCatch(tag, @lib.Expr(body)) => {
              buf.write_byte(0x07)
              if Encode::encode(tag, buf) is Err(err) {
                return Err(err)
              }
              work.push(ControlSequence(body, 0))
            }
            @lib.LegacyCatchAll(@lib.Expr(body)) => {
              buf.write_byte(0x19)
              work.push(ControlSequence(body, 0))
            }
          }
        }
      ControlInstruction(instruction) =>
        match instruction {
          Block(bt, @lib.Expr(body)) | Loop(bt, @lib.Expr(body)) => {
            buf.write_byte(if instruction is Block(_, _) { 0x02 } else { 0x03 })
            if Encode::encode(bt, buf) is Err(err) {
              return Err(err)
            }
            work.push(ControlByte(0x0B))
            work.push(ControlSequence(body, 0))
          }
          If(bt, then_body, else_body) => {
            buf.write_byte(0x04)
            if Encode::encode(bt, buf) is Err(err) {
              return Err(err)
            }
            work.push(ControlByte(0x0B))
            if else_body is Some(body) {
              work.push(ControlSequence(body, 0))
              work.push(ControlByte(0x05))
            }
            work.push(ControlSequence(then_body, 0))
          }
          Try(bt, @lib.Expr(body), catches, delegate) => {
            if (catches.is_empty() && delegate is None) ||
              (!catches.is_empty() && delegate is Some(_)) {
              return Err(BinaryEncodeError::InvalidLegacyTryShape)
            }
            buf.write_byte(0x06)
            if Encode::encode(bt, buf) is Err(err) {
              return Err(err)
            }
            match delegate {
              Some(label) => work.push(ControlDelegate(label))
              None => {
                work.push(ControlByte(0x0B))
                work.push(ControlCatches(catches, 0))
              }
            }
            work.push(ControlSequence(body, 0))
          }
          TryTable(bt, catches, @lib.Expr(body)) => {
            buf.write_byte(0x1F)
            if Encode::encode(bt, buf) is Err(err) {
              return Err(err)
            }
            if Encode::encode(catches, buf) is Err(err) {
              return Err(err)
            }
            work.push(ControlByte(0x0B))
            work.push(ControlSequence(body, 0))
          }
          _ =>
            if encode_leaf_instruction(instruction, buf) is Err(err) {
              return Err(err)
            }
        }
    }
  }
  Ok(())
}
