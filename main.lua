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

  for height = 0.3, 1.5, 0.4 do
    local pose = mat4():rotate(math.pi/8, 0,1,0):translate(0, height, -1)
    local size = vec3(0.3, 0.4, 0.2)
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
end

function lovr.update(dt)
  -- override collision resolver to notify all colliders that have registered their callbacks
  world:update(framerate, function(world)
    world:computeOverlaps()
    for shapeA, shapeB in world:overlaps() do
      local areColliding = world:collide(shapeA, shapeB)
      if areColliding then
        cbA = collisionCallbacks[shapeA]
        if cbA then cbA(shapeB:getCollider(), world) end
        cbB = collisionCallbacks[shapeB]
        if cbB then cbB(shapeA:getCollider(), world) end
      end
    end
  end)
  -- hand updates - location, orientation, solidify on trigger button, grab on grip button
  for i, hand in pairs(lovr.headset.getHands()) do
    -- align collider with controller by applying force (position) and torque (orientation)
    local rw = mat4(lovr.headset.getPose(hand))   -- real world pose of controllers
    local vr = mat4(hands.colliders[i]:getPose()) -- vr pose of palm colliders
    local angle, ax,ay,az = quat(rw):mul(quat(vr):conjugate()):unpack()
    angle = ((angle + math.pi) % (2 * math.pi) - math.pi) -- for minimal motion wrap to (-pi, +pi) range
    hands.colliders[i]:applyTorque(vec3(ax, ay, az):mul(angle * dt * 1))
    hands.colliders[i]:applyForce((vec3(rw:mul(0,0,0)) - vec3(vr:mul(0,0,0))):mul(dt * 2000))
    -- solidify when trigger touched
    hands.solid[i] = lovr.headset.isDown(hand, 'trigger')
    hands.colliders[i]:getShapes()[1]:setSensor(not hands.solid[i])
    -- hold/release colliders
    if lovr.headset.isDown(hand, 'grip') and hands.touching[i] and not hands.holding[i] then
      hands.holding[i] = hands.touching[i]
      lovr.physics.newBallJoint(hands.colliders[i], hands.holding[i], vr:mul(0,0,0))
      lovr.physics.newSliderJoint(hands.colliders[i], hands.holding[i], quat(vr):direction())
    end
    if lovr.headset.wasReleased(hand, 'grip') and hands.holding[i] then
      for _,joint in ipairs(hands.colliders[i]:getJoints()) do
        joint:destroy()
      end
      hands.holding[i] = nil
    end
  end
end

function lovr.draw()
  lovr.graphics.skybox(skybox)

  -- create floor and walls
  lovr.graphics.setColor(0x203166)
  lovr.graphics.cylinder(0,-1,0, 3,  math.pi/2,  1,0,0,  10)
  make_boxes(0.5, 4, 8, 0x304176)

  for i, collider in ipairs(hands.colliders) do
    local alpha = hands.solid[i] and 1 or 0.2
    lovr.graphics.setColor(0.75, 0.56, 0.44, alpha)
    drawBoxCollider(collider)
  end
  lovr.math.setRandomSeed(0)
  for i, collider in ipairs(boxes) do
    local shade = 0.2 + 0.6 * lovr.math.random()
    lovr.graphics.setColor(shade, shade, shade)
    drawBoxCollider(collider)
  end
end

function drawBoxCollider(collider)
  -- query current pose (location and orientation)
  local pose = mat4(collider:getPose())
  -- query dimensions of box
  local shape = collider:getShapes()[1]
  local size = vec3(shape:getDimensions())
  -- draw box
  pose:scale(size)
  lovr.graphics.box('fill', pose)
end

function registerCollisionCallback(collider, callback)
  collisionCallbacks = collisionCallbacks or {}
  for _, shape in ipairs(collider:getShapes()) do
    collisionCallbacks[shape] = callback
  end
  -- to be called with arguments callback(otherCollider, world) from update function
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
