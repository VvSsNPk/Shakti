import ShaktiLean

open WaylandProtocol

-- Example: Query the wl_display interface
def showDisplay : IO Unit := do
  IO.println "=== Wayland Display Interface ==="
  IO.println s!"Name: {wlDisplay.name}"
  IO.println s!"Version: {wlDisplay.version}"
  IO.println s!"Description: {wlDisplay.description}"
  IO.println "\nRequests:"
  for req in wlDisplay.requests do
    IO.println s!"  - {req.name}: {req.description}"
  IO.println "\nEvents:"
  for evt in wlDisplay.events do
    IO.println s!"  - {evt.name}: {evt.description}"

-- Example: Show all interfaces
def showAllInterfaces : IO Unit := do
  IO.println "\n=== All Wayland Interfaces ==="
  for iface in allInterfaces do
    IO.println s!"  • {iface.name} (v{iface.version})"

-- Example: Protocol statistics
def showStats : IO Unit := do
  IO.println "\n=== Protocol Statistics ==="
  IO.println s!"Total interfaces: {allInterfaces.length}"
  IO.println s!"Total requests: {totalRequests}"
  IO.println s!"Total events: {totalEvents}"

-- Example: Find an interface
def showSurface : IO Unit := do
  IO.println "\n=== Wayland Surface Interface ==="
  match findInterface "wl_surface" allInterfaces with
  | none => IO.println "Surface interface not found"
  | some surf =>
    IO.println s!"Name: {surf.name} (v{surf.version})"
    IO.println "Requests:"
    for req in surf.requests do
      IO.println s!"  - {req.name} ({req.args.length} args)"
    IO.println "Events:"
    for evt in surf.events do
      IO.println s!"  - {evt.name} ({evt.args.length} args)"

def main : IO Unit := do
  showDisplay
  showAllInterfaces
  showStats
  showSurface
  IO.println "\n✓ Wayland Protocol Formalization Complete"
