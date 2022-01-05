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
  box:setFriction(100)
  box:setKinematic(true)

  -- make walls
  make_boxes(1, 4, 6, 0x304176)

  -- make boxes to play with
  for depth = 0, 0.6, 0.2 do
    for width = 0, 0.6, 0.2 do
      for height = 0.1, 0.8, 0.13 do
        local pose = mat4():rotate(-0.7, 0,1,0):translate(width, height, -0.6 - depth)
        local size = vec3(0.09, 0.13, 0.18)
        local box = world:newBoxCollider(vec3(pose), size)
        box:setOrientation(quat(pose))
        box:setFriction(100)
        table.insert(boxes, box)
      end
    end
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

  -- add lighting per lovr-phong
  -- set up shader
  defaultVertex = [[
        out vec3 FragmentPos;
        out vec3 Normal;

        vec4 position(mat4 projection, mat4 transform, vec4 vertex) {
            Normal = lovrNormalMatrix * lovrNormal;
            FragmentPos = (lovrModel * vertex).xyz;

            return projection * transform * vertex;
        }
  ]]
  defaultFragment = [[
        uniform vec4 liteColor;

        uniform vec4 ambience;

        in vec3 Normal;
        in vec3 FragmentPos;
        uniform vec3 lightPos;

        uniform vec3 viewPos;
        uniform float specularStrength;
        uniform float metallic;

        vec4 color(vec4 graphicsColor, sampler2D image, vec2 uv)
        {
            //diffuse
            vec3 norm = normalize(Normal);
            vec3 lightDir = normalize(lightPos - FragmentPos);
            float diff = max(dot(norm, lightDir), 0.0);
            vec4 diffuse = diff * liteColor;

            //specular
            vec3 viewDir = normalize(viewPos - FragmentPos);
            vec3 reflectDir = reflect(-lightDir, norm);
            float spec = pow(max(dot(viewDir, reflectDir), 0.0), metallic);
            vec4 specular = specularStrength * spec * liteColor;

            vec4 baseColor = graphicsColor * texture(image, uv);
            //vec4 objectColor = baseColor * vertexColor;

            return baseColor * (ambience + diffuse + specular);
        }
  ]]
  shader = lovr.graphics.newShader(defaultVertex, defaultFragment, {})

  -- Set default shader values
  shader:send('liteColor', {1.0, 1.0, 1.0, 1.0})
  shader:send('ambience', {0.05, 0.05, 0.05, 1.0})
  shader:send('specularStrength', 0.5)
  shader:send('metallic', 32.0)
end

function lovr.update(dt)
  -- set light position
  shader:send('lightPos', {-2, 4.0, 1.0})

  -- Adjust head position (for specular)
  if lovr.headset then
      hx, hy, hz = lovr.headset.getPosition()
      shader:send('viewPos', { hx, hy, hz } )
  end

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
  lovr.graphics.setColor(0xdFdFdF)
  lovr.graphics.skybox(skybox)

  lovr.graphics.setShader(shader)

  -- create floor and walls
  lovr.graphics.setColor(0x203166)
  lovr.graphics.box('fill', 0, 0, 0, 20, 0.1, 20)

  for i, collider in ipairs(hands.colliders) do
    local alpha = hands.solid[i] and 1 or 0.2
    lovr.graphics.setColor(0.75, 0.56, 0.44, alpha)
    drawBoxCollider(collider)
  end
  lovr.math.setRandomSeed(0)
  for i, collider in ipairs(boxes) do
    vx, vy, vz = collider:getLinearVelocity()
    local shade = math.abs(vx) + math.abs(vy) + math.abs(vz)
    lovr.graphics.setColor(shade, 0.5, 0.5)
    drawBoxCollider(collider)
  end

  lovr.graphics.setShader() -- Reset to default/unlit
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
    local pose = mat4():rotate(angle, 0,1,0):translate(0, height/2.0, distance)
    --pose:rotate(angle + lovr.timer.getTime() / 10,  0,1,0) -- rotate over Y axis
    --pose:rotate(angle, 0,0,1) -- rotate over Y axis
    --pose:translate(0, height/2.0, -distance)  -- move away from origin
    --pose:rotate(2*angle, 0,1,0) -- rotate over Y axis
    pose:scale(width, height, 0.1) -- block size
    local size = vec3(width, height, 0.1)
    local box = world:newBoxCollider(vec3(pose), size)
    --box:setOrientation(quat(pose))
    box:setKinematic(true)
    table.insert(boxes, box)
    lovr.graphics.box('fill', pose)
  end
end

 -- want to make those little walls colliders
 -- there are no cool floating objects out there
 -- I can't look at a sensible browser, just use oculus browser

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
