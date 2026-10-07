import ShaktiLean.Basic
import ShaktiLean.Protocol
import ShaktiLean.Utils

namespace WaylandProtocol

-- Runtime value representation for serialization
inductive Value where
  | intV (n : Int32) : Value
  | uintV (n : UInt32) : Value
  | stringV (s : String) : Value
  | objectV (id : UInt32) : Value
  | fdV (fd : Nat) : Value
  | arrayV (data : ByteArray) : Value

-- Helper: encode little-endian UInt32
def encodeUInt32LE (n : UInt32) : List UInt8 :=
  [
    (n >>> 0).toUInt8,
    (n >>> 8).toUInt8,
    (n >>> 16).toUInt8,
    (n >>> 24).toUInt8
  ]

-- Helper: encode little-endian Int32
def encodeInt32LE (n : Int32) : List UInt8 :=
  encodeUInt32LE (n.toUInt32)

-- Helper: encode little-endian UInt16
def encodeUInt16LE (n : UInt16) : List UInt8 :=
  [
    (n >>> 0).toUInt8,
    (n >>> 8).toUInt8
  ]

-- Helper: get byte at offset, default to 0
def getByte (data : List UInt8) (offset : Nat) : UInt8 :=
  data.getD offset 0

-- Helper: decode little-endian UInt32
def decodeUInt32LE (data : List UInt8) (offset : Nat) : Option UInt32 := do
  if offset + 4 > data.length then none
  else
    let b0 := (getByte data offset).toUInt32
    let b1 := (getByte data (offset + 1)).toUInt32
    let b2 := (getByte data (offset + 2)).toUInt32
    let b3 := (getByte data (offset + 3)).toUInt32
    some (b0 ||| (b1 <<< 8) ||| (b2 <<< 16) ||| (b3 <<< 24))

-- Helper: decode little-endian Int32
def decodeInt32LE (data : List UInt8) (offset : Nat) : Option Int32 := do
  let u ← decodeUInt32LE data offset
  some u.toInt32

-- Helper: decode little-endian UInt16
def decodeUInt16LE (data : List UInt8) (offset : Nat) : Option UInt16 := do
  if offset + 2 > data.length then none
  else
    let b0 := (getByte data offset).toUInt16
    let b1 := (getByte data (offset + 1)).toUInt16
    some (b0 ||| (b1 <<< 8))

-- Helper: calculate padded size (align to 4 bytes)
def padAlign (size : Nat) : Nat :=
  let remainder := size % 4
  if remainder = 0 then size else size + (4 - remainder)

-- Helper: create padding bytes
def paddingBytes (size : Nat) : List UInt8 :=
  let remainder := size % 4
  let padCount := if remainder = 0 then 0 else 4 - remainder
  List.replicate padCount 0

-- Encode a single argument value
def encodeValue (v : Value) : List UInt8 :=
  match v with
  | .intV n => encodeInt32LE n
  | .uintV n => encodeUInt32LE n
  | .stringV s =>
    let encoded := s.toUTF8.toList
    let len := encoded.length + 1
    let lenBytes := encodeUInt32LE len.toUInt32
    let nullTerminator : List UInt8 := [0]
    let padding := paddingBytes (4 + encoded.length + 1)
    lenBytes ++ encoded ++ nullTerminator ++ padding
  | .objectV id => encodeUInt32LE id
  | .fdV fd => encodeUInt32LE fd.toUInt32
  | .arrayV data =>
    let byteList := data.toList
    let sizeBytes := encodeUInt32LE byteList.length.toUInt32
    let padding := paddingBytes (4 + byteList.length)
    sizeBytes ++ byteList ++ padding

-- Encode a complete message
def encodeMessage (senderId : UInt32) (opcode : UInt16) (args : List Value) : List UInt8 :=
  let argData := args.map encodeValue |> (fun lists => lists.foldl (· ++ ·) [])

  let headerSize := 8
  let totalSize := headerSize + argData.length
  let sizeWords := totalSize / 4

  let senderIdBytes := encodeUInt32LE senderId
  let sizeBytes := encodeUInt16LE sizeWords.toUInt16
  let opcodeBytes := encodeUInt16LE opcode

  senderIdBytes ++ sizeBytes ++ opcodeBytes ++ argData

-- Decode message header
def decodeMessageHeader (data : List UInt8) : Option (UInt32 × UInt16 × UInt16 × Nat) := do
  if data.length < 8 then none
  else
    let senderId ← decodeUInt32LE data 0
    let sizeWords ← decodeUInt16LE data 4
    let opcode ← decodeUInt16LE data 6
    let totalBytes := sizeWords.toNat * 4
    some (senderId, sizeWords, opcode, totalBytes)

-- Decode a single value by type
def decodeValue (argType : ArgType) (data : List UInt8) (offset : Nat) :
    Option (Value × Nat) := do
  match argType with
  | ArgType.int =>
    let n ← decodeInt32LE data offset
    some (.intV n, offset + 4)
  | ArgType.uint =>
    let n ← decodeUInt32LE data offset
    some (.uintV n, offset + 4)
  | ArgType.string =>
    let len ← decodeUInt32LE data offset
    let lenNat := len.toNat
    if offset + 4 + lenNat > data.length then none
    else
      let strBytes := (data.drop (offset + 4)).take (lenNat - 1)
      let s := String.fromUTF8! (ByteArray.mk (strBytes.toArray))
      let paddedLen := padAlign (4 + lenNat)
      some (.stringV s, offset + paddedLen)
  | ArgType.object =>
    let id ← decodeUInt32LE data offset
    some (.objectV id, offset + 4)
  | ArgType.newId =>
    let id ← decodeUInt32LE data offset
    some (.objectV id, offset + 4)
  | ArgType.fd =>
    let fd ← decodeUInt32LE data offset
    some (.fdV fd.toNat, offset + 4)
  | ArgType.array =>
    let len ← decodeUInt32LE data offset
    let lenNat := len.toNat
    if offset + 4 + lenNat > data.length then none
    else
      let arrBytes := (data.drop (offset + 4)).take lenNat
      let paddedLen := padAlign (4 + lenNat)
      some (.arrayV (ByteArray.mk (arrBytes.toArray)), offset + paddedLen)
  | ArgType.fixed =>
    let n ← decodeUInt32LE data offset
    some (.uintV n, offset + 4)

-- Decode all arguments for a message
def decodeMessageArgs (argTypes : List ArgType) (data : List UInt8) (startOffset : Nat) :
    Option (List Value) := do
  let rec go (types : List ArgType) (offset : Nat) (acc : List Value) :
      Option (List Value) := do
    match types with
    | [] => some acc.reverse
    | t :: rest =>
      let (value, newOffset) ← decodeValue t data offset
      go rest newOffset (value :: acc)
  go argTypes startOffset []

-- Serialize a message given its definition and values
def serializeRequest (interfaceName : String) (messageName : String) (args : List Value) :
    Option (List UInt8) := do
  let iface ← findInterface interfaceName allInterfaces
  let msg ← findByName messageName iface.requests

  if args.length ≠ msg.args.length then none
  else
    some (encodeMessage 1 messageName.hash.toUInt16 args)

end WaylandProtocol
