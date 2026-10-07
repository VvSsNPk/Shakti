import Std

-- Display initialization and rendering via C FFI
-- Calls into Rust display library (shakti_display)

namespace ShaktiDisplay

-- FFI functions exported from Rust
@[extern "display_init"]
opaque display_init : IO UInt32

@[extern "display_render_frame"]
opaque display_render_frame : IO UInt32

@[extern "display_get_frame_count"]
opaque display_get_frame_count : IO UInt64

@[extern "display_get_elapsed_ms"]
opaque display_get_elapsed_ms : IO UInt64

@[extern "display_shutdown"]
opaque display_shutdown : IO Unit

-- Lean wrapper types and functions

structure DisplayHandle where
  initialized : Bool

def displayCreate : IO DisplayHandle := do
  let result ← display_init
  pure ⟨result ≠ 0⟩

def displayRenderFrame : IO Bool := do
  let result ← display_render_frame
  pure (result ≠ 0)

def displayGetFrameCount : IO UInt64 := do
  display_get_frame_count

def displayGetElapsedMs : IO UInt64 := do
  display_get_elapsed_ms

def displayShutdown : IO Unit := do
  display_shutdown

-- Main render loop for Lean compositor
-- This is called from Lean's Main.lean
def compositorMainLoop (maxFrames : Nat := 600) : IO Unit := do
  let display ← displayCreate

  if not display.initialized then
    IO.println "Error: Failed to initialize display"
    return

  IO.println ""
  let rec renderLoop (frame : Nat) : IO Unit := do
    if frame >= maxFrames then
      IO.println "\nCompleted target frame count"
      return

    -- Render one frame (includes compositor logic)
    let success ← displayRenderFrame

    if not success then
      IO.println "\nError: Frame rendering failed"
      return

    renderLoop (frame + 1)

  renderLoop 0

  -- Shutdown
  displayShutdown
  elapsed ← displayGetElapsedMs
  frames ← displayGetFrameCount

  IO.println s"\n✓ Total frames: {frames}"
  IO.println s"✓ Elapsed: {elapsed}ms"

end ShaktiDisplay
