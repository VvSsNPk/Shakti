import ShaktiLean.EventLoop
import ShaktiLean.Renderer

namespace WaylandProtocol

-- Simple FFI exports without opaque type wrappers
-- These work directly with the Lean types through C FFI

-- Global mutable state (simplified for FFI)
-- In a real implementation, this would use proper state management

variable (compositorState : CompositorState) in
variable (rendererState : RendererState) in

-- Initialize compositor state
@[export compositor_create]
def compositorCreate : UInt64 := 1

-- Get frame time
@[export compositor_get_frame_time]
def compositorGetFrameTime : UInt32 := 0

-- Get frame count
@[export compositor_get_frame_count]
def compositorGetFrameCount : UInt32 := 0

-- Initialize renderer
@[export renderer_create]
def rendererCreate : UInt64 := 1

-- Get renderer frame number
@[export renderer_get_frame_number]
def rendererGetFrameNumber : UInt32 := 0

-- Get target FPS
@[export renderer_get_fps]
def rendererGetFps : UInt32 := 60

-- Version info
@[export compositor_version]
def compositorVersion : UInt32 := 100

@[export compositor_version_major]
def compositorVersionMajor : UInt32 := 1

@[export compositor_version_minor]
def compositorVersionMinor : UInt32 := 0

-- Simple status function for testing
@[export compositor_is_ready]
def compositorIsReady : UInt32 := 1

end WaylandProtocol
