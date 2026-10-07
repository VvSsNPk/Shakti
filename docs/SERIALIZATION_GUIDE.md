# Wayland Protocol Serialization Guide

This guide explains the Wayland wire protocol format and provides inspiration for implementing serialization in Lean 4.

## Key Resources

### 1. **Protocol Specification** (Official)
- [Wayland Protocol Specification](https://wayland.freedesktop.org/)
- Complete XML definition of all interfaces and messages
- Argument types and their encoding
- Official reference

### 2. **Reference Implementation** (libwayland)
- [libwayland C Implementation](https://gitlab.freedesktop.org/wayland/wayland)
- Ring buffer management for I/O
- Actual serialization code
- File descriptor passing mechanism

## Wayland Wire Protocol Format

### Message Structure (on the wire)

Every Wayland message has this binary format:

```
[4 bytes] sender_id (uint32)  - object ID that sent/receives message
[2 bytes] message_size (uint16) - total size including header (size/4 in 32-bit words)
[2 bytes] message_opcode (uint16) - which request/event this is

[variable] arguments - serialized arguments, 4-byte aligned
```

**Example**: `wl_display.sync(callback)`
```
sender_id:    0x00000001       (wl_display object)
size:         0x0008           (8 words = 32 bytes total)
opcode:       0x0000           (sync is first request, opcode 0)
callback_id:  0x00000002       (new object ID to create)
```

### Argument Type Encoding

Each type encodes to a fixed size (all padded to 4-byte alignment):

| Type | Size | Format | Example |
|------|------|--------|---------|
| `int` | 4 | 32-bit signed little-endian | `-1` → `FF FF FF FF` |
| `uint` | 4 | 32-bit unsigned little-endian | `100` → `64 00 00 00` |
| `fixed` | 4 | 24.8 fixed point (int * 256) | `1.5` → `00 04 00 00` |
| `string` | 4+N+pad | `[length][data][null-terminator][padding]` | `"hi"` → `03 00 00 00 68 69 00 00` |
| `object` | 4 | 32-bit object ID | `obj42` → `2A 00 00 00` |
| `new_id` | 4 | 32-bit new object ID | `new42` → `2A 00 00 00` |
| `fd` | 4 | File descriptor index in ancillary data | `fd0` → `00 00 00 00` |
| `array` | 4+N+pad | `[size][data][padding]` | `[1,2,3]` → `0C 00 00 00 [data]` |

### String Encoding (Detailed)

Strings are null-terminated and padded to 4-byte boundary:

```
"hello" (5 chars):
  06 00 00 00       - length (6 including null terminator)
  68 65 6c 6c 6f 00 - "hello\0" 
  00 00             - padding to align to 4-byte boundary
```

### File Descriptor Passing

FDs are not sent in the message itself, but via ancillary data (cmsg):
- A message with FD arguments contains indices (0, 1, 2, ...)
- The actual FDs are sent separately via `sendmsg()`
- Receiver uses `recvmsg()` to get the FDs

## Implementation Approach in Lean 4

### Step 1: Define Serializable Types

```lean
-- Value type to represent runtime values
inductive Value where
  | intV (n : Int32) : Value
  | uintV (n : UInt32) : Value
  | stringV (s : String) : Value
  | objectV (id : UInt32) : Value
  | fdV (fd : Nat) : Value
  | arrayV (data : ByteArray) : Value
  deriving Repr

-- Size calculation
def Value.size : Value → Nat
  | .intV _ => 4
  | .uintV _ => 4
  | .stringV s => 
    let len := s.length + 1  -- include null terminator
    let padded := (len + 3) / 4 * 4  -- align to 4 bytes
    4 + padded  -- include size field
  | .objectV _ => 4
  | .fdV _ => 4
  | .arrayV data => 4 + data.size
```

### Step 2: Encode Individual Values

```lean
def encodeValue : Value → ByteArray
  | .intV n => encodeInt32LE n
  | .uintV n => encodeUInt32LE n
  | .stringV s =>
    let len := s.length + 1
    let header := encodeUInt32LE len.toUInt32
    let data := s.toUTF8 ++ #[0]  -- add null terminator
    let padLen := (4 - (data.size % 4)) % 4
    let padding := ByteArray.mk (List.replicate padLen 0 |>.toArray)
    header ++ data ++ padding
  | .objectV id => encodeUInt32LE id
  | .fdV fd => encodeUInt32LE fd.toUInt32
  | .arrayV data => encodeUInt32LE data.size.toUInt32 ++ data
```

### Step 3: Encode Complete Message

```lean
def encodeMessage (senderId : UInt32) (opcode : UInt16) (args : List Value) : ByteArray := 
  let argData := args.map encodeValue |> ByteArray.concat
  
  -- Calculate total size (in 32-bit words)
  let headerSize := 8  -- 4 bytes ID + 2 bytes size + 2 bytes opcode
  let totalSize := headerSize + argData.size
  let sizeWords := totalSize / 4
  
  -- Build header
  let senderIdBytes := encodeUInt32LE senderId
  let sizeBytes := encodeUInt16LE sizeWords.toUInt16
  let opcodeBytes := encodeUInt16LE opcode
  
  senderIdBytes ++ sizeBytes ++ opcodeBytes ++ argData
```

### Step 4: Decode Messages

```lean
def decodeMessage (data : ByteArray) : Option (UInt32 × UInt16 × List Value) := do
  -- Extract header
  let senderId ← decodeUInt32LE data 0
  let sizeWords ← decodeUInt16LE data 4
  let opcode ← decodeUInt16LE data 6
  let totalBytes := sizeWords.toNat * 4
  
  -- Extract argument bytes
  let argData := data.extract 8 totalBytes
  
  -- Decode arguments based on message type
  -- (you'd look up the message definition to know arg types)
  some (senderId, opcode, [])
```

## Practical Implementation Strategy

### Phase 1: Basic Serialization (Start Here)

```lean
-- ShaktiLean/Serialization.lean
namespace WaylandProtocol

-- Helper functions for byte encoding
def encodeUInt32LE (n : UInt32) : ByteArray := sorry
def encodeInt32LE (n : Int32) : ByteArray := sorry
def encodeUInt16LE (n : UInt16) : ByteArray := sorry

def decodeUInt32LE (data : ByteArray) (offset : Nat) : Option UInt32 := sorry
def decodeInt32LE (data : ByteArray) (offset : Nat) : Option Int32 := sorry

-- Value type for runtime data
inductive Value where
  | intV (n : Int32) : Value
  | uintV (n : UInt32) : Value
  | stringV (s : String) : Value
  | objectV (id : UInt32) : Value
  | fdV (fd : Nat) : Value
  | arrayV (data : ByteArray) : Value

-- Encoding
def encodeValue (v : Value) : ByteArray := sorry
def encodeMessage (senderId : UInt32) (opcode : UInt16) (args : List Value) : ByteArray := sorry

-- Decoding
def decodeValue (argType : ArgType) (data : ByteArray) (offset : Nat) : Option (Value × Nat) := sorry
def decodeMessage (data : ByteArray) : Option (UInt32 × UInt16 × ByteArray) := sorry

end WaylandProtocol
```

### Phase 2: Type-Driven Serialization

```lean
-- Make serialization tied to message definitions
def serializeRequest (req : Message) (args : List Value) : Option ByteArray := do
  -- Verify args match request signature
  let validated ← validateArgumentTypes req.args args
  pure (encodeMessage 0 0 validated)

def deserializeEvent (event : Message) (data : ByteArray) : Option (List Value) := do
  -- Verify received data matches event signature
  sorry
```

### Phase 3: Bidirectional Codecs

```lean
-- Combine encoding and decoding
class MessageCodec (α : Type) where
  encode : α → ByteArray
  decode : ByteArray → Option α

instance : MessageCodec (UInt32 × UInt16 × List Value) where
  encode := fun (id, op, args) => encodeMessage id op args
  decode := fun data => do
    let (id, op, _) ← decodeMessage data
    sorry  -- would need arg definitions to decode values
```

## Testing Your Implementation

```lean
-- Test encoding matches libwayland
example : encodeMessage 1 0 [.uintV 100] = expected_bytes := by
  decide

-- Test round-trip
example : 
  let original := [.stringV "hello", .intV (-42)]
  let encoded := encodeMessage 1 0 original
  let decoded := decodeMessage encoded
  decoded = some (1, 0, original) := by
  sorry
```

## Reference: Common Message Examples

### wl_display.sync (client → server)
```
[01 00 00 00] - wl_display (ID 1)
[08 00] - 8 words (32 bytes)
[00 00] - opcode 0 (sync)
[02 00 00 00] - new object ID (callback = 2)
```

### wl_display.get_registry (client → server)
```
[01 00 00 00] - wl_display
[08 00] - 8 words
[01 00] - opcode 1 (get_registry)
[03 00 00 00] - new object ID (registry = 3)
```

### wl_registry.bind (client → server)
```
[03 00 00 00] - wl_registry
[XX 00] - size
[00 00] - opcode 0 (bind)
[01 00 00 00] - name (which interface)
[XX 00 00 00] - version
[04 00 00 00] - new object ID
```

## Next Steps

1. **Implement basic byte encoding/decoding** (endianness, alignment)
2. **Test with simple types** (int, uint, object IDs)
3. **Add string support** (null termination, padding)
4. **Handle arrays and complex types**
5. **Integrate with Connection layer** (socket I/O)
6. **Add FD passing support** (ancillary data)

## Inspiration Sources

- **[Libwayland C implementation](https://gitlab.freedesktop.org/wayland/wayland)** - Ring buffers and serialization
- **[Wayland Protocol Specification](https://wayland.freedesktop.org/)** - Official protocol reference
- **Rust implementation**: Look at `wayland-rs` for Rust patterns
- **Go implementation**: Look at `go-wayland` for different approach

The key insight: **Serialization is just structured binary packing with careful attention to alignment and byte order.**
