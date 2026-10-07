import ShaktiLean

open WaylandProtocol ShaktiDisplay

def showSystemInfo : IO Unit := do
  IO.println ""
  IO.println "ShaktiLean Compositor Framework"
  IO.println "===============================\n"

  IO.println "✓ Phase 0: Serialization (Value encoding/decoding)"
  IO.println "✓ Phase 1: Connections (Ring buffers, connection pooling)"
  IO.println "✓ Phase 2: State Machines (Object lifecycle management)"
  IO.println "✓ Phase 3: Event Loop (Message processing)"
  IO.println "✓ Phase 4: Graphics FFI (OpenGL ES bindings)"

  IO.println ""
  IO.println "Protocol Coverage:"
  IO.println "  • 16 Wayland interfaces"
  IO.println "  • 39 requests"
  IO.println "  • 32 events"

  IO.println ""
  IO.println "Key Features:"
  IO.println "  • Type-safe protocol messages"
  IO.println "  • Multi-client support"
  IO.println "  • Efficient ring buffer I/O"
  IO.println "  • State machine validation"
  IO.println "  • Damage tracking"
  IO.println "  • Frame statistics"

def runCompositorDisplay : IO Unit := do
  showSystemInfo
  IO.println ""
  IO.println "═════════════════════════════════════════════"
  IO.println ""
  compositorMainLoop 600

def main : IO Unit := do
  runCompositorDisplay
