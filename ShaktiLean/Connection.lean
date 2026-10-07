import ShaktiLean.Basic
import ShaktiLean.Serialization

namespace WaylandProtocol

-- Ring buffer for efficient I/O operations
structure RingBuffer where
  data : ByteArray
  head : Nat
  tail : Nat

def RingBuffer.create (capacity : Nat) : RingBuffer :=
  ⟨ByteArray.mk (Array.replicate capacity 0), 0, 0⟩

def RingBuffer.capacity (rb : RingBuffer) : Nat :=
  rb.data.size

def RingBuffer.availableRead (rb : RingBuffer) : Nat :=
  if rb.tail >= rb.head then
    rb.tail - rb.head
  else
    rb.capacity - rb.head + rb.tail

def RingBuffer.availableWrite (rb : RingBuffer) : Nat :=
  rb.capacity - rb.availableRead - 1

def RingBuffer.isEmpty (rb : RingBuffer) : Bool :=
  rb.head == rb.tail

def RingBuffer.isFull (rb : RingBuffer) : Bool :=
  rb.availableWrite == 0

def RingBuffer.write (rb : RingBuffer) (bytes : List UInt8) : Option RingBuffer := do
  let bytesLen := bytes.length
  if bytesLen > rb.availableWrite then none
  else
    let processedData := bytes.foldl (fun (buf : ByteArray × Nat) (byte : UInt8) =>
      let offset := buf.2
      let writePos := (rb.tail + offset) % rb.capacity
      (buf.1.set! writePos byte, offset + 1)
    ) (rb.data, 0)

    let newTail := (rb.tail + bytesLen) % rb.capacity
    some { rb with data := processedData.1, tail := newTail }

def RingBuffer.peek (rb : RingBuffer) (count : Nat) : List UInt8 :=
  if count > rb.availableRead then []
  else
    let rec peekHelper (idx : Nat) (acc : List UInt8) : List UInt8 :=
      if idx >= count then acc.reverse
      else
        let readPos := (rb.head + idx) % rb.capacity
        peekHelper (idx + 1) (rb.data.get! readPos :: acc)
    peekHelper 0 []

def RingBuffer.read (rb : RingBuffer) (count : Nat) : Option (List UInt8 × RingBuffer) := do
  if count > rb.availableRead then none
  else
    let bytes := rb.peek count
    let newHead := (rb.head + count) % rb.capacity
    some (bytes, { rb with head := newHead })

def RingBuffer.clear (rb : RingBuffer) : RingBuffer :=
  { rb with head := 0, tail := 0 }

-- Client connection state
structure ClientConnection where
  id : Nat
  inBuffer : RingBuffer
  outBuffer : RingBuffer
  objectIds : List Nat
  connected : Bool

def ClientConnection.create (clientId : Nat) (bufferSize : Nat := 4096) : ClientConnection :=
  ⟨clientId, RingBuffer.create bufferSize, RingBuffer.create bufferSize, [1], true⟩

def ClientConnection.allocateObjectId (conn : ClientConnection) : ClientConnection × Nat :=
  let maxId := conn.objectIds.foldl Nat.max 0
  let newId := maxId + 1
  ({ conn with objectIds := conn.objectIds ++ [newId] }, newId)

def ClientConnection.queueIncomingMessage (conn : ClientConnection) (msgBytes : List UInt8) :
    Option ClientConnection := do
  let newInBuffer ← conn.inBuffer.write msgBytes
  some { conn with inBuffer := newInBuffer }

def ClientConnection.queueOutgoingMessage (conn : ClientConnection) (msgBytes : List UInt8) :
    Option ClientConnection := do
  let newOutBuffer ← conn.outBuffer.write msgBytes
  some { conn with outBuffer := newOutBuffer }

-- Helper to get byte from list safely
def getByteFromList (bytes : List UInt8) (idx : Nat) : UInt8 :=
  bytes.getD idx 0

def ClientConnection.readMessage (conn : ClientConnection) : Option (List UInt8 × ClientConnection) := do
  if conn.inBuffer.availableRead < 8 then none
  else
    let header := conn.inBuffer.peek 8
    if header.length < 8 then none
    else
      let b0 := (getByteFromList header 4).toUInt16
      let b1 := (getByteFromList header 5).toUInt16
      let sizeWords := (b1 <<< 8) ||| b0
      let totalBytes := sizeWords.toNat * 4

      if totalBytes > conn.inBuffer.availableRead then none
      else
        let (msgBytes, newInBuffer) ← conn.inBuffer.read totalBytes
        some (msgBytes, { conn with inBuffer := newInBuffer })

def ClientConnection.getPendingMessages (conn : ClientConnection) : List UInt8 :=
  conn.outBuffer.peek conn.outBuffer.availableRead

def ClientConnection.flushOutgoing (conn : ClientConnection) : Option ClientConnection :=
  let clearBuffer := conn.outBuffer.clear
  some { conn with outBuffer := clearBuffer }

-- Connection pool for managing multiple clients
structure ConnectionPool where
  connections : List ClientConnection
  nextClientId : Nat

def ConnectionPool.create : ConnectionPool :=
  ⟨[], 0⟩

def ConnectionPool.addConnection (pool : ConnectionPool) : ConnectionPool × Nat :=
  let conn := ClientConnection.create pool.nextClientId
  let newPool := { pool with
    connections := pool.connections ++ [conn],
    nextClientId := pool.nextClientId + 1
  }
  (newPool, pool.nextClientId)

def ConnectionPool.findConnection (pool : ConnectionPool) (clientId : Nat) :
    Option ClientConnection :=
  pool.connections.find? (fun c => c.id == clientId)

def ConnectionPool.updateConnection (pool : ConnectionPool) (clientId : Nat)
    (updater : ClientConnection → ClientConnection) : ConnectionPool :=
  let newConns := pool.connections.map (fun c =>
    if c.id == clientId then updater c else c)
  { pool with connections := newConns }

def ConnectionPool.removeConnection (pool : ConnectionPool) (clientId : Nat) : ConnectionPool :=
  let newConns := pool.connections.filter (fun c => c.id ≠ clientId)
  { pool with connections := newConns }

def ConnectionPool.getAllPendingMessages (pool : ConnectionPool) :
    List (Nat × List UInt8) :=
  pool.connections.filterMap (fun c =>
    if c.outBuffer.availableRead > 0 then
      some (c.id, c.outBuffer.peek c.outBuffer.availableRead)
    else
      none)

-- Statistics about connection pool
structure PoolStats where
  totalConnections : Nat
  totalInBuffered : Nat
  totalOutBuffered : Nat

def ConnectionPool.getStats (pool : ConnectionPool) : PoolStats :=
  let totalIn := pool.connections.foldl (fun acc c => acc + c.inBuffer.availableRead) 0
  let totalOut := pool.connections.foldl (fun acc c => acc + c.outBuffer.availableRead) 0
  ⟨pool.connections.length, totalIn, totalOut⟩

end WaylandProtocol
