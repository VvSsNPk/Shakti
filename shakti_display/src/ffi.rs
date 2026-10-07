// FFI bindings to Lean compositor
// Using pure Rust stubs for now - full Lean linking to be integrated

// Stub implementations of FFI functions
pub fn compositor_create() -> u64 { 1 }
pub fn compositor_get_frame_time() -> u32 { 0 }
pub fn compositor_get_frame_count() -> u32 { 0 }
pub fn compositor_version() -> u32 { 100 }
pub fn compositor_version_major() -> u32 { 1 }
pub fn compositor_version_minor() -> u32 { 0 }
pub fn compositor_is_ready() -> u32 { 1 }

pub fn renderer_create() -> u64 { 1 }
pub fn renderer_get_frame_number() -> u32 { 0 }
pub fn renderer_get_fps() -> u32 { 60 }

pub struct CompositorFFI {
    pub initialized: bool,
}

pub struct RendererFFI {
    pub initialized: bool,
}

impl CompositorFFI {
    pub fn new() -> Self {
        let state = compositor_create();
        CompositorFFI {
            initialized: state != 0,
        }
    }

    pub fn iterate(&mut self) {
        // Pure function - no state to update in stub version
    }

    pub fn get_frame_time(&self) -> u32 {
        if self.initialized {
            compositor_get_frame_time()
        } else {
            0
        }
    }

    pub fn get_frame_count(&self) -> u32 {
        if self.initialized {
            compositor_get_frame_count()
        } else {
            0
        }
    }

    pub fn is_ready(&self) -> bool {
        if self.initialized {
            compositor_is_ready() != 0
        } else {
            false
        }
    }

    pub fn version() -> (u32, u32, u32) {
        (
            compositor_version_major(),
            compositor_version_minor(),
            0,
        )
    }
}

impl RendererFFI {
    pub fn new() -> Self {
        let state = renderer_create();
        RendererFFI {
            initialized: state != 0,
        }
    }

    pub fn iterate(&mut self) {
        // Pure function - no state to update in stub version
    }

    pub fn get_frame_number(&self) -> u32 {
        if self.initialized {
            renderer_get_frame_number()
        } else {
            0
        }
    }

    pub fn get_fps(&self) -> u32 {
        if self.initialized {
            renderer_get_fps()
        } else {
            60
        }
    }
}

impl Default for CompositorFFI {
    fn default() -> Self {
        Self::new()
    }
}

impl Default for RendererFFI {
    fn default() -> Self {
        Self::new()
    }
}
