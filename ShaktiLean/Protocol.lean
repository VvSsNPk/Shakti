import ShaktiLean.Basic

namespace WaylandProtocol

-- Helper to create enum entries more concisely
def mkEntry (name : String) (value : Nat) (summary : String) : EnumEntry :=
  ⟨name, value, summary⟩

def mkArg (name : String) (argType : ArgType) (interfaceName : Option String) (summary : String) : Arg :=
  ⟨name, argType, interfaceName, summary⟩

def mkMessage (name : String) (description : String) (destructor : Bool) (args : List Arg) : Message :=
  ⟨name, description, destructor, args⟩

def mkEnum (name : String) (description : String) (entries : List EnumEntry) : Enum :=
  ⟨name, description, entries⟩

def mkInterface (name : String) (version : Nat) (description : String)
    (requests : List Message) (events : List Message) (enums : List Enum) : Interface :=
  ⟨name, version, description, requests, events, enums⟩

-- ============ Enums ============

def seatCapability : Enum :=
  mkEnum "capability" "Seat capabilities" [
    mkEntry "pointer" 1 "the seat has pointer devices",
    mkEntry "keyboard" 2 "the seat has keyboard devices",
    mkEntry "touch" 4 "the seat has touch devices"
  ]

def keyboardKeyState : Enum :=
  mkEnum "key_state" "Physical key state" [
    mkEntry "released" 0 "key is not pressed",
    mkEntry "pressed" 1 "key is pressed"
  ]

def pointerButtonState : Enum :=
  mkEnum "button_state" "Physical button state" [
    mkEntry "released" 0 "button is not pressed",
    mkEntry "pressed" 1 "button is pressed"
  ]

def pointerAxis : Enum :=
  mkEnum "axis" "Pointer axis" [
    mkEntry "vertical_scroll" 0 "vertical axis",
    mkEntry "horizontal_scroll" 1 "horizontal axis"
  ]

def pointerAxisSource : Enum :=
  mkEnum "axis_source" "Axis source" [
    mkEntry "wheel" 0 "scrolling wheel",
    mkEntry "finger" 1 "finger on touch surface",
    mkEntry "continuous" 2 "continuous source",
    mkEntry "wheel_tilt" 3 "wheel tilt"
  ]

def outputSubpixel : Enum :=
  mkEnum "subpixel" "Output subpixel geometry" [
    mkEntry "unknown" 0 "unknown geometry",
    mkEntry "vertical_rgb" 1 "vertical rgb layout",
    mkEntry "vertical_bgr" 2 "vertical bgr layout",
    mkEntry "horizontal_rgb" 3 "horizontal rgb layout",
    mkEntry "horizontal_bgr" 4 "horizontal bgr layout"
  ]

def outputTransform : Enum :=
  mkEnum "transform" "Output transformation" [
    mkEntry "normal" 0 "no transform",
    mkEntry "rotate_90" 1 "90 degree rotation",
    mkEntry "rotate_180" 2 "180 degree rotation",
    mkEntry "rotate_270" 3 "270 degree rotation",
    mkEntry "flipped" 4 "flipped",
    mkEntry "flipped_rotate_90" 5 "flipped and 90 degree rotated",
    mkEntry "flipped_rotate_180" 6 "flipped and 180 degree rotated",
    mkEntry "flipped_rotate_270" 7 "flipped and 270 degree rotated"
  ]

def outputMode : Enum :=
  mkEnum "mode" "Output mode" [
    mkEntry "current" 1 "current mode",
    mkEntry "preferred" 2 "preferred mode"
  ]

def shellSurfaceResize : Enum :=
  mkEnum "resize" "Resize edge" [
    mkEntry "none" 0 "no edge",
    mkEntry "top" 1 "top edge",
    mkEntry "bottom" 2 "bottom edge",
    mkEntry "left" 4 "left edge",
    mkEntry "top_left" 5 "top-left corner",
    mkEntry "bottom_left" 6 "bottom-left corner",
    mkEntry "right" 8 "right edge",
    mkEntry "top_right" 9 "top-right corner",
    mkEntry "bottom_right" 10 "bottom-right corner"
  ]

-- ============ Interface Definitions ============

def wlDisplay : Interface :=
  mkInterface "wl_display" 1 "Core global object"
    [
      mkMessage "sync" "Asynchronous roundtrip" false
        [mkArg "callback" .newId (some "wl_callback") "callback object"],
      mkMessage "get_registry" "Get global registry object" false
        [mkArg "registry" .newId (some "wl_registry") "global registry"]
    ]
    [
      mkMessage "error" "Fatal error event" false [
        mkArg "object_id" .object none "object where error occurred",
        mkArg "code" .uint none "error code",
        mkArg "message" .string none "error description"
      ],
      mkMessage "delete_id" "Server has deleted object" false
        [mkArg "id" .uint none "deleted object id"]
    ]
    [
      mkEnum "error" "Global error values" [
        mkEntry "invalid_object" 0 "server couldn't find object",
        mkEntry "invalid_method" 1 "method doesn't exist",
        mkEntry "no_memory" 2 "server out of memory",
        mkEntry "implementation" 3 "implementation error"
      ]
    ]

def wlRegistry : Interface :=
  mkInterface "wl_registry" 1 "Global registry object"
    [
      mkMessage "bind" "Bind global object" false [
        mkArg "name" .uint none "numeric name",
        mkArg "id" .newId none "object interface"
      ]
    ]
    [
      mkMessage "global" "Global object announcement" false [
        mkArg "name" .uint none "numeric name",
        mkArg "interface" .string none "interface name",
        mkArg "version" .uint none "interface version"
      ],
      mkMessage "global_remove" "Global object removed" false
        [mkArg "name" .uint none "numeric name"]
    ]
    []

def wlCallback : Interface :=
  mkInterface "wl_callback" 1 "Callback object"
    []
    [
      mkMessage "done" "Done event" true
        [mkArg "callback_data" .uint none "callback data"]
    ]
    []

def wlCompositor : Interface :=
  mkInterface "wl_compositor" 7 "The compositor singleton"
    [
      mkMessage "create_surface" "Create new surface" false
        [mkArg "id" .newId (some "wl_surface") "new surface"],
      mkMessage "create_region" "Create new region" false
        [mkArg "id" .newId (some "wl_region") "new region"],
      mkMessage "release" "Release compositor" true []
    ]
    []
    []

def wlSurface : Interface :=
  mkInterface "wl_surface" 7 "An onscreen surface"
    [
      mkMessage "destroy" "Destroy surface" true [],
      mkMessage "attach" "Set the buffer for this surface" false [
        mkArg "buffer" .object (some "wl_buffer") "buffer",
        mkArg "x" .int none "x offset",
        mkArg "y" .int none "y offset"
      ],
      mkMessage "damage" "Mark part of surface as damaged" false [
        mkArg "x" .int none "x coordinate",
        mkArg "y" .int none "y coordinate",
        mkArg "width" .int none "width",
        mkArg "height" .int none "height"
      ],
      mkMessage "frame" "Request frame callback" false
        [mkArg "callback" .newId (some "wl_callback") "callback"],
      mkMessage "set_opaque_region" "Set opaque region" false
        [mkArg "region" .object (some "wl_region") "region"],
      mkMessage "set_input_region" "Set input region" false
        [mkArg "region" .object (some "wl_region") "region"],
      mkMessage "commit" "Commit pending surface changes" false []
    ]
    [
      mkMessage "enter" "Surface entered output" false [
        mkArg "output" .object (some "wl_output") "output"
      ],
      mkMessage "leave" "Surface left output" false
        [mkArg "output" .object (some "wl_output") "output"]
    ]
    [
      mkEnum "error" "Surface errors" [
        mkEntry "invalid_scale" 0 "buffer scale invalid",
        mkEntry "invalid_transform" 1 "buffer transform invalid"
      ]
    ]

def wlBuffer : Interface :=
  mkInterface "wl_buffer" 1 "Content for a wl_surface"
    [mkMessage "destroy" "Destroy buffer" true []]
    [mkMessage "release" "Buffer is released" false []]
    []

def wlRegion : Interface :=
  mkInterface "wl_region" 7 "Rectangular region"
    [
      mkMessage "destroy" "Destroy region" true [],
      mkMessage "add" "Add rectangle to region" false [
        mkArg "x" .int none "x coordinate",
        mkArg "y" .int none "y coordinate",
        mkArg "width" .int none "width",
        mkArg "height" .int none "height"
      ],
      mkMessage "subtract" "Subtract rectangle from region" false [
        mkArg "x" .int none "x coordinate",
        mkArg "y" .int none "y coordinate",
        mkArg "width" .int none "width",
        mkArg "height" .int none "height"
      ]
    ]
    []
    []

def wlSeat : Interface :=
  mkInterface "wl_seat" 11 "Group of input devices"
    [
      mkMessage "get_pointer" "Return pointer object" false
        [mkArg "id" .newId (some "wl_pointer") "pointer"],
      mkMessage "get_keyboard" "Return keyboard object" false
        [mkArg "id" .newId (some "wl_keyboard") "keyboard"],
      mkMessage "get_touch" "Return touch object" false
        [mkArg "id" .newId (some "wl_touch") "touch"],
      mkMessage "release" "Release seat" true []
    ]
    [
      mkMessage "capabilities" "Seat capability change" false
        [mkArg "capabilities" .uint none "capabilities"],
      mkMessage "name" "Seat name" false
        [mkArg "name" .string none "seat name"]
    ]
    [seatCapability]

def wlPointer : Interface :=
  mkInterface "wl_pointer" 11 "Pointer input device"
    [
      mkMessage "set_cursor" "Set cursor image" false [
        mkArg "serial" .uint none "serial number",
        mkArg "surface" .object (some "wl_surface") "cursor surface",
        mkArg "hotspot_x" .int none "hotspot x",
        mkArg "hotspot_y" .int none "hotspot y"
      ],
      mkMessage "release" "Release pointer" true []
    ]
    [
      mkMessage "enter" "Pointer entered surface" false [
        mkArg "serial" .uint none "serial",
        mkArg "surface" .object (some "wl_surface") "surface",
        mkArg "surface_x" .fixed none "x coordinate",
        mkArg "surface_y" .fixed none "y coordinate"
      ],
      mkMessage "leave" "Pointer left surface" false [
        mkArg "serial" .uint none "serial",
        mkArg "surface" .object (some "wl_surface") "surface"
      ],
      mkMessage "motion" "Pointer motion" false [
        mkArg "time" .uint none "timestamp",
        mkArg "surface_x" .fixed none "x coordinate",
        mkArg "surface_y" .fixed none "y coordinate"
      ],
      mkMessage "button" "Pointer button" false [
        mkArg "serial" .uint none "serial",
        mkArg "time" .uint none "timestamp",
        mkArg "button" .uint none "button code",
        mkArg "state" .uint none "state"
      ],
      mkMessage "axis" "Pointer axis scroll" false [
        mkArg "time" .uint none "timestamp",
        mkArg "axis" .uint none "axis",
        mkArg "value" .fixed none "value"
      ],
      mkMessage "frame" "Pointer frame" false []
    ]
    [pointerButtonState, pointerAxis, pointerAxisSource]

def wlKeyboard : Interface :=
  mkInterface "wl_keyboard" 11 "Keyboard input device"
    [mkMessage "release" "Release keyboard" true []]
    [
      mkMessage "keymap" "Keyboard keymap" false [
        mkArg "format" .uint none "keymap format",
        mkArg "fd" .fd none "keymap file descriptor",
        mkArg "size" .uint none "keymap size"
      ],
      mkMessage "enter" "Keyboard entered surface" false [
        mkArg "serial" .uint none "serial",
        mkArg "surface" .object (some "wl_surface") "surface",
        mkArg "keys" .array none "pressed keys"
      ],
      mkMessage "leave" "Keyboard left surface" false [
        mkArg "serial" .uint none "serial",
        mkArg "surface" .object (some "wl_surface") "surface"
      ],
      mkMessage "key" "Key event" false [
        mkArg "serial" .uint none "serial",
        mkArg "time" .uint none "timestamp",
        mkArg "key" .uint none "key code",
        mkArg "state" .uint none "key state"
      ],
      mkMessage "modifiers" "Modifier keys" false [
        mkArg "serial" .uint none "serial",
        mkArg "mods_depressed" .uint none "mods depressed",
        mkArg "mods_latched" .uint none "mods latched",
        mkArg "mods_locked" .uint none "mods locked",
        mkArg "group" .uint none "group"
      ]
    ]
    [
      mkEnum "keymap_format" "Keymap format" [
        mkEntry "xkb_v1" 1 "XKB keymap"
      ],
      keyboardKeyState
    ]

def wlTouch : Interface :=
  mkInterface "wl_touch" 11 "Touch input device"
    [mkMessage "release" "Release touch" true []]
    [
      mkMessage "down" "Touch down" false [
        mkArg "serial" .uint none "serial",
        mkArg "time" .uint none "timestamp",
        mkArg "surface" .object (some "wl_surface") "surface",
        mkArg "id" .int none "touch id",
        mkArg "x" .fixed none "x coordinate",
        mkArg "y" .fixed none "y coordinate"
      ],
      mkMessage "up" "Touch up" false [
        mkArg "serial" .uint none "serial",
        mkArg "time" .uint none "timestamp",
        mkArg "id" .int none "touch id"
      ],
      mkMessage "motion" "Touch motion" false [
        mkArg "time" .uint none "timestamp",
        mkArg "id" .int none "touch id",
        mkArg "x" .fixed none "x coordinate",
        mkArg "y" .fixed none "y coordinate"
      ],
      mkMessage "frame" "Touch frame" false [],
      mkMessage "cancel" "Touch cancel" false []
    ]
    []

def wlOutput : Interface :=
  mkInterface "wl_output" 4 "Output device (display)"
    [mkMessage "release" "Release output" true []]
    [
      mkMessage "geometry" "Output geometry" false [
        mkArg "x" .int none "x coordinate",
        mkArg "y" .int none "y coordinate",
        mkArg "physical_width" .int none "physical width",
        mkArg "physical_height" .int none "physical height",
        mkArg "subpixel" .int none "subpixel layout",
        mkArg "make" .string none "manufacturer",
        mkArg "model" .string none "model name",
        mkArg "transform" .int none "transform"
      ],
      mkMessage "mode" "Output mode" false [
        mkArg "flags" .uint none "flags",
        mkArg "width" .int none "width",
        mkArg "height" .int none "height",
        mkArg "refresh" .int none "refresh rate"
      ]
    ]
    [outputSubpixel, outputTransform, outputMode]

def wlShm : Interface :=
  mkInterface "wl_shm" 3 "Shared memory pool"
    [
      mkMessage "create_pool" "Create shared memory pool" false [
        mkArg "id" .newId (some "wl_shm_pool") "pool",
        mkArg "fd" .fd none "file descriptor",
        mkArg "size" .int none "pool size"
      ],
      mkMessage "release" "Release shm" true []
    ]
    [
      mkMessage "format" "Supported format" false
        [mkArg "format" .uint none "format"]
    ]
    [
      mkEnum "format" "Shared memory format" [
        mkEntry "argb8888" 0 "ARGB 8:8:8:8",
        mkEntry "xrgb8888" 1 "XRGB 8:8:8:8"
      ]
    ]

def wlShmPool : Interface :=
  mkInterface "wl_shm_pool" 3 "Shared memory pool"
    [
      mkMessage "create_buffer" "Create buffer" false [
        mkArg "id" .newId (some "wl_buffer") "buffer",
        mkArg "offset" .int none "offset",
        mkArg "width" .int none "width",
        mkArg "height" .int none "height",
        mkArg "stride" .int none "stride",
        mkArg "format" .uint none "format"
      ],
      mkMessage "destroy" "Destroy pool" true []
    ]
    []
    []

def wlShell : Interface :=
  mkInterface "wl_shell" 1 "Shell interface"
    [
      mkMessage "get_shell_surface" "Get shell surface" false [
        mkArg "id" .newId (some "wl_shell_surface") "shell surface",
        mkArg "surface" .object (some "wl_surface") "surface"
      ]
    ]
    []
    []

def wlShellSurface : Interface :=
  mkInterface "wl_shell_surface" 1 "Desktop shell surface"
    [
      mkMessage "pong" "Respond to ping" false
        [mkArg "serial" .uint none "serial"],
      mkMessage "move" "Start move operation" false [
        mkArg "seat" .object (some "wl_seat") "seat",
        mkArg "serial" .uint none "serial"
      ],
      mkMessage "resize" "Start resize operation" false [
        mkArg "seat" .object (some "wl_seat") "seat",
        mkArg "serial" .uint none "serial",
        mkArg "edges" .uint none "edges"
      ],
      mkMessage "set_toplevel" "Make surface toplevel" false [],
      mkMessage "set_transient" "Make surface transient" false [
        mkArg "parent" .object (some "wl_surface") "parent",
        mkArg "x" .int none "x offset",
        mkArg "y" .int none "y offset",
        mkArg "flags" .uint none "flags"
      ],
      mkMessage "set_fullscreen" "Make fullscreen" false [
        mkArg "method" .uint none "method",
        mkArg "framerate" .uint none "framerate",
        mkArg "output" .object (some "wl_output") "output"
      ],
      mkMessage "set_title" "Set surface title" false
        [mkArg "title" .string none "title"],
      mkMessage "set_class" "Set surface class" false
        [mkArg "class_" .string none "class"]
    ]
    [
      mkMessage "ping" "Ping event" false
        [mkArg "serial" .uint none "serial"],
      mkMessage "configure" "Configure event" false [
        mkArg "edges" .uint none "edges",
        mkArg "width" .int none "width",
        mkArg "height" .int none "height"
      ],
      mkMessage "popup_done" "Popup is done" false []
    ]
    [
      shellSurfaceResize,
      mkEnum "transient" "Transient type" [
        mkEntry "inactive" 0 "inactive"
      ],
      mkEnum "fullscreen_method" "Fullscreen method" [
        mkEntry "default" 0 "default",
        mkEntry "scale" 1 "scale",
        mkEntry "driver" 2 "driver",
        mkEntry "fill" 3 "fill"
      ]
    ]

-- All interfaces in the Wayland protocol
def allInterfaces : List Interface := [
  wlDisplay, wlRegistry, wlCallback, wlCompositor, wlSurface, wlBuffer, wlRegion,
  wlSeat, wlPointer, wlKeyboard, wlTouch, wlOutput, wlShm, wlShmPool,
  wlShell, wlShellSurface
]

end WaylandProtocol
