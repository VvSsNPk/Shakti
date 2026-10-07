# Phase 1: Socket Integration & Ring Buffers

## Overview

Phase 1 provides the foundation for managing client connections and buffering Wayland protocol messages. It includes:

- **Ring Buffer**: Efficient circular buffer for I/O operations
- **Client Connection**: Per-client message queuing and state
- **Connection Pool**: Multi-client management

## Architecture

```
                    Wayland Clients
                          |
                    [Socket Layer]
                          |
        ┌─────────────────┴─────────────────┐
        |                                   |
    ClientConnection              ClientConnection
    - id: Nat                      - id: Nat
    - inBuffer: RingBuffer         - inBuffer: RingBuffer
    - outBuffer: RingBuffer        - outBuffer: RingBuffer
    - objectIds: List Nat          - objectIds: List Nat
        |                              |
        └──────────────────┬──────────┘
                           |
                   ConnectionPool
                   - connections: List
                   - nextClientId: Nat
```

## Ring Buffer - Circular I/O Buffer

A ring buffer is a fixed-size circular buffer ideal for streaming I/O:

```
Capacity: 12 bytes
Initial state: head=0, tail=0

After write "Hello": (5 bytes)
[H][e][l][l][o][ ][ ][ ][ ][ ][ ][ ]
 0  1  2  3  4  5  6  7  8  9 10 11
 ↑
head=0, tail=5

After write "World": (5 bytes)
[H][e][l][l][o][W][o][r][l][d][ ][ ]
 0  1  2  3  4  5  6  7  8  9 10 11
 ↑                                   
head=0, tail=10

After read "Hello": (5 bytes)
[H][e][l][l][o][W][o][r][l][d][ ][ ]
                 ↑                   
            head=5, tail=10
```

### API

```lean
-- Create a ring buffer with given capacity
def RingBuffer.create (capacity : Nat) : RingBuffer

-- Write bytes (returns None if buffer full)
def RingBuffer.write (rb : RingBuffer) (bytes : List UInt8) : Option RingBuffer

-- Peek without consuming
def RingBuffer.peek (rb : RingBuffer) (count : Nat) : List UInt8

-- Read and consume
def RingBuffer.read (rb : RingBuffer) (count : Nat) : Option (List UInt8 × RingBuffer)

-- Query state
def RingBuffer.availableRead (rb : RingBuffer) : Nat
def RingBuffer.availableWrite (rb : RingBuffer) : Nat
def RingBuffer.isEmpty (rb : RingBuffer) : Bool
def RingBuffer.isFull (rb : RingBuffer) : Bool

-- Clear buffer
def RingBuffer.clear (rb : RingBuffer) : RingBuffer
```

## Client Connection - Per-Client State

Manages state for a single client connection:

```lean
structure ClientConnection where
  id : Nat                    -- Unique client identifier
  inBuffer : RingBuffer       -- Incoming message bytes from client
  outBuffer : RingBuffer      -- Outgoing message bytes to client
  objectIds : List Nat        -- Object IDs allocated to this client
  connected : Bool            -- Connection status
```

### API

```lean
-- Create new client connection
def ClientConnection.create (clientId : Nat) (bufferSize : Nat := 4096) : ClientConnection

-- Allocate new object ID (for wl_registry.bind, etc.)
def ClientConnection.allocateObjectId (conn : ClientConnection) : ClientConnection × Nat

-- Queue incoming message bytes
def ClientConnection.queueIncomingMessage (conn : ClientConnection) (msgBytes : List UInt8) :
    Option ClientConnection

-- Queue outgoing message bytes (to send to client)
def ClientConnection.queueOutgoingMessage (conn : ClientConnection) (msgBytes : List UInt8) :
    Option ClientConnection

-- Read one complete message from incoming buffer
-- Parses message header to get total size, then reads complete message
def ClientConnection.readMessage (conn : ClientConnection) : 
    Option (List UInt8 × ClientConnection)

-- Get all pending outgoing messages
def ClientConnection.getPendingMessages (conn : ClientConnection) : List UInt8

-- Clear outgoing buffer after sending
def ClientConnection.flushOutgoing (conn : ClientConnection) : Option ClientConnection
```

## Connection Pool - Multi-Client Management

Manages all active client connections:

```lean
structure ConnectionPool where
  connections : List ClientConnection
  nextClientId : Nat
```

### API

```lean
-- Create new pool
def ConnectionPool.create : ConnectionPool

-- Add new client connection
def ConnectionPool.addConnection (pool : ConnectionPool) : ConnectionPool × Nat

-- Find connection by ID
def ConnectionPool.findConnection (pool : ConnectionPool) (clientId : Nat) : 
    Option ClientConnection

-- Update connection with custom function
def ConnectionPool.updateConnection (pool : ConnectionPool) (clientId : Nat) 
    (updater : ClientConnection → ClientConnection) : ConnectionPool

-- Remove client connection
def ConnectionPool.removeConnection (pool : ConnectionPool) (clientId : Nat) : ConnectionPool

-- Get all pending messages across all clients
def ConnectionPool.getAllPendingMessages (pool : ConnectionPool) : 
    List (Nat × List UInt8)

-- Get pool statistics
def ConnectionPool.getStats (pool : ConnectionPool) : PoolStats
```

## Usage Examples

### Example 1: Creating a Connection Pool

```lean
open WaylandProtocol

-- Create empty pool
let pool := ConnectionPool.create

-- Add first client
let (pool1, clientId1) := pool.addConnection
-- clientId1 = 0

-- Add second client
let (pool2, clientId2) := pool1.addConnection
-- clientId2 = 1

-- Now pool2 has 2 clients
#eval pool2.connections.length  -- 2
```

### Example 2: Queueing Messages

```lean
-- Send message to client
match ConnectionPool.findConnection pool clientId with
| some conn =>
  let msgBytes : List UInt8 := encodeMessage 1 0 [Value.objectV 2]
  match ClientConnection.queueOutgoingMessage conn msgBytes with
  | some updatedConn =>
    let updatedPool := ConnectionPool.updateConnection pool clientId (fun _ => updatedConn)
    ()  -- pool now has message queued for client
  | none => ()  -- buffer full
| none => ()  -- client not found
```

### Example 3: Reading Messages from Client

```lean
-- Receive message from client
match ConnectionPool.findConnection pool clientId with
| some conn =>
  match ClientConnection.readMessage conn with
  | some (msgBytes, updatedConn) =>
    -- Process msgBytes (deserialize to get requests, events, etc.)
    let updatedPool := ConnectionPool.updateConnection pool clientId (fun _ => updatedConn)
    ()
  | none =>
    -- Either no complete message available or error
    ()
| none => ()
```

### Example 4: Allocating Object IDs

```lean
-- When client calls wl_registry.bind, allocate new object
match ConnectionPool.findConnection pool clientId with
| some conn =>
  let (updatedConn, newObjId) := ClientConnection.allocateObjectId conn
  -- newObjId is guaranteed unique for this client
  let updatedPool := ConnectionPool.updateConnection pool clientId (fun _ => updatedConn)
  ()
| none => ()
```

### Example 5: Broadcasting Messages

```lean
-- Send event to all clients (or multiple clients)
let msgBytes : List UInt8 := encodeMessage someObj someOp []

let updatedPool := pool.connections.foldl (fun updatedPool conn =>
  match ClientConnection.queueOutgoingMessage conn msgBytes with
  | some newConn => ConnectionPool.updateConnection updatedPool conn.id (fun _ => newConn)
  | none => updatedPool  -- skip if buffer full
) pool
```

## Data Flow

### Receiving Message from Client

```
1. Socket receives bytes
2. ClientConnection.queueIncomingMessage()  -- writes to inBuffer
3. ClientConnection.readMessage()          -- extracts complete message
4. Deserialize message using Serialization module
5. Handle message (invoke request handler, etc.)
6. Generate response events
7. ClientConnection.queueOutgoingMessage() -- writes to outBuffer
8. Socket sends bytes from outBuffer
```

### Message Header Format

Messages in buffers have this structure:

```
Offset  Size  Field
------  ----  --------------------
0       4     sender_id (UInt32 LE)
4       2     size_words (UInt16 LE)  ← readMessage uses this
6       2     opcode (UInt16 LE)
8       N     arguments
```

`readMessage()` reads bytes 4-5 to get message size in 32-bit words, multiplies by 4 to get byte count, then reads that many bytes total.

## Performance Characteristics

### Ring Buffer

- **Write**: O(n) where n = number of bytes (but handles wrapping efficiently)
- **Read**: O(n)
- **Peek**: O(n)
- **Space**: O(c) where c = capacity (fixed)

### Connection Pool

- **Add connection**: O(1) amortized
- **Find connection**: O(k) where k = number of connections
- **Update connection**: O(k)
- **Remove connection**: O(k)

### Optimization Notes

For production with thousands of clients:
- Consider HashMap for connection lookup instead of List.find?
- Use pre-allocated byte arrays instead of List UInt8
- Batch message processing
- Stream to socket asynchronously

## Integration Points

Phase 1 integrates with:

- **Serialization** (Phase 0): Encodes/decodes messages for queueing
- **StateMachine** (Phase 2): Will validate message sequences
- **EventLoop** (Phase 3): Drives the read/write cycle

## Testing

Basic sanity tests:

```lean
-- Test ring buffer write/read
let rb := RingBuffer.create 100
match RingBuffer.write rb [1, 2, 3] with
| some rb1 =>
  match RingBuffer.read rb1 3 with
  | some (bytes, rb2) =>
    #eval bytes  -- [1, 2, 3]
  | none => ()
| none => ()

-- Test connection pool
let pool := ConnectionPool.create
let (pool1, id1) := pool.addConnection
let (pool2, id2) := pool1.addConnection

match ConnectionPool.findConnection pool2 id1 with
| some conn =>
  #eval conn.id  -- id1
  #eval conn.objectIds  -- [1]
| none => ()
```

## Next Phase

Phase 2 will add:
- State machines for object lifecycle
- Message validation
- Protocol state tracking

This will ensure messages are sent/received at the right times in the right states.
