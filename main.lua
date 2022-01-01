local hands = { -- palms that can push and grab objects
  colliders = {nil, nil},     -- physical objects for palms
  touching  = {nil, nil},     -- the collider currently touched by each hand
  holding   = {nil, nil},     -- the collider attached to palm
  solid     = {false, false}, -- hand can either pass through objects or be solid
} -- to be filled with as many hands as there are active controllers

local world
local collisionCallbacks = {}
local boxes = {}

local framerate = 1 / 72 -- fixed framerate is recommended for physics updates

function lovr.load()
  skybox = lovr.graphics.newTexture('space.png')
  world = lovr.physics.newWorld(0, -2, 0, false) -- low gravity and no collider sleeping
  local box = world:newBoxCollider(vec3(0, 0, 0), vec3(20, 0.1, 20))
  box:setKinematic(true)
end

function lovr.update(dt)
end

function lovr.draw()
  lovr.graphics.skybox(skybox)

  -- create floor and walls
  lovr.graphics.setColor(0x203166)
  lovr.graphics.cylinder(0,-1,0, 3,  math.pi/2,  1,0,0,  10)
  make_boxes(0.5, 4, 8, 0x304176)

  for height = 0.3, 1.2, 0.3 do
    local pose = mat4():translate(0, height, -1)
    local size = vec3(0.3, 0.3, 0.2)
    local box = world:newBoxCollider(vec3(pose), size)
    box:setOrientation(quat(pose))
    table.insert(boxes, box)
  end
  
  -- make colliders for two hands
  for i = 1, 2 do
    hands.colliders[i] = world:newBoxCollider(vec3(0,2,0), vec3(0.04, 0.08, 0.08))
    hands.colliders[i]:setLinearDamping(0.2)
    hands.colliders[i]:setAngularDamping(0.3)
    hands.colliders[i]:setMass(0.1)
    registerCollisionCallback(hands.colliders[i],
      function(collider, world)
        -- store collider that was last touched by hand
        hands.touching[i] = collider
      end)
  end

  -- draw hands
  lovr.graphics.setColor(0xd2b793)
  for _, handName in ipairs(lovr.headset.getHands()) do
    local skeleton = lovr.headset.getSkeleton(handName)
    if skeleton then
      for _, bone in ipairs(skeleton) do
        lovr.graphics.sphere(mat4(unpack(bone)):scale(0.004, 0.002, 0.006))
      end
    else
      local handPose = mat4(lovr.headset.getPose(handName))
      handPose:scale(0.04, 0.08, 0.12)
      lovr.graphics.box('fill', handPose)
    end
  end
end

function make_boxes(height, width, distance, color)
  lovr.graphics.setColor(color)
  for angle = 0, math.pi * 2, math.pi / 6 do
    local pose = mat4()
    pose:rotate(angle, 0,1,0) -- rotate over Y axis
    --pose:rotate(angle + lovr.timer.getTime() / 10,  0,1,0) -- rotate over Y axis
    pose:translate(0, 0.7, -distance)  -- move away from origin
    pose:scale(width, height, 0.1) -- block size
    lovr.graphics.box('fill', pose)
  end
end

 -- I don't see any stars
 -- there are no cool floating objects out there
 -- there's nothing to interact with
 -- Editor should spawn lower and angled, with smaller text
 -- I can't do git stuff
 -- I can't look at a sensible browser
 -- no vim keybindings

-- Ctrl+Shift+Home centers the editor to be in front of camera
-- F10 toggles the 'fullscreen' mode for current editor
-- Ctrl+P spawns a new editor
-- Ctrl+Tab selects next editor
-- Ctrl+W closes current editor
-- Ctrl+O lists files for opening in current editor
-- Ctrl+S saves changes to opened file
-- Ctrl+H opens LOVR API documentation in a separate editor
-- Ctrl+Shift+S stores current editors into a session file
-- Ctrl+Shift+L opens editors loaded from a session file
-- Ctrl+Shift+P runs code profiler for duration of one second and shows the report in separate editor
