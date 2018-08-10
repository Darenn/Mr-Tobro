pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
--lowrezjam
--by darenn keller

--Game
tile_size = 4
g_pixel_size = 64
g_row_tiles_count = 64 / tile_size 

g_player = nil

deltatime = 1/30 -- because we're running at 30 fps

g_bullets = {}

-- 2d matrix containing buildings
g_map_buildings = {}
  for x=0, g_row_tiles_count do
    g_map_buildings[x] = {}
    for y=0, g_row_tiles_count do
      g_map_buildings[x][y] = nil
    end
  end

function _init()
  -- make the game in 64x64
  poke(0x5f2c,3)
  
  g_player = create_player(6, 6)
  create_bullet(0, 6 * 4, 1, 1, {x=1, y=0}, 15, 12)
  create_building(7, 7, 1, building_type.canon)
  --bullet2 = create_bullet(10, 6 * 4, 1, 1, {x=-1, y=0}, 1, 12)
end

function _update()
  
  update_bullets()
end


function update_bullets()
  -- make a copy to allow removal from g_bullets
  copy = shallow_copy(g_bullets)
  for bullet in all(copy) do
    update_bullet(bullet)
  end
end

function _draw()
  cls()
  map(0, 0, 0, 0, 8, 8)
  update_player(g_player)
  draw_player(g_player)
  draw_buildings()
  draw_bullets()
end

function draw_bullets()
  for bullet in all(copy) do
    draw_bullet(bullet)
  end
end

function draw_buildings()
  for x=0, g_row_tiles_count do
    for y=0, g_row_tiles_count do
      local building = g_map_buildings[x][y]
      if (building != nil) then
        draw_building(building)
      end
    end
  end
end

--Rendering
-- render the nth sprite top left quarter on the tile at (tile_x, tile_y)
function render_tiled_sprite(n, tile_x, tile_y, orientation)
  orientation = orientation or e_orientation.right
  spr(n, tile_x * tile_size, tile_y * tile_size, 0.5, 0.5)
end

-- render the nth sprite top left quarter on the pixel (x ,y)
function render_sprite(n, x, y)
  spr(n, x, y, 0.5, 0.5)
end

function get_pixel_pos(tile_x, tile_y)
  local pos = {x=-1, y=-1}
  pos.x = tile_x * tile_size
  pos.y = tile_y * tile_size
  return pos
end

e_orientation = {}
e_orientation.right = 0
e_orientation.down = 1
e_orientation.left = 2
e_orientation.up = 3

--Player
function update_player(_player)
  
  -- activate
  if (btnp(4)) then
    building = g_map_buildings[_player.pos.x][_player.pos.y]
    if (building != nil) then
      building.activate(building)
    end
  end
  
  -- move
  local new_position = {}
  new_position.x = _player.pos.x
  new_position.y = _player.pos.y
  if (btnp(0)) then
    new_position.x -= 1
  elseif (btnp(1)) then
    new_position.x += 1
  elseif (btnp(2)) then
    new_position.y -= 1
  elseif (btnp(3)) then
    new_position.y += 1
  end
  if (is_walkable(new_position)) then
    _player.pos = new_position
  end
end

function draw_player(_player)
  render_tiled_sprite(_player.sprite_id, _player.pos.x, _player.pos.y)
end


function create_player(x, y)
  _player = {}
    _player.pos = {}
    _player.pos.x = x -- x and y are tile positions
    _player.pos.y = y
    _player.sprite_id = 11
  return _player
end

--Collision
walkable_tile = 2

-- x and y are tile positions
function is_walkable(x, y)
  return mget(x / 2, y / 2) == walkable_tile
end

function is_walkable(position)
  return mget(position.x / 2, position.y / 2) == walkable_tile
end

function collide(obj, other)
    if
        other.pos.x+other.hitbox.x+other.hitbox.w > obj.pos.x+obj.hitbox.x and 
        other.pos.y+other.hitbox.y+other.hitbox.h > obj.pos.y+obj.hitbox.y and
        other.pos.x+other.hitbox.x < obj.pos.x+obj.hitbox.x+obj.hitbox.w and
        other.pos.y+other.hitbox.y < obj.pos.y+obj.hitbox.y+obj.hitbox.h 
    then
        return true
    end
end

--Utils
-- converts anything to string, even nested tables
function tostring(any)
    if type(any)=="function" then 
        return "function" 
    end
    if any==nil then 
        return "nil" 
    end
    if type(any)=="string" then
        return any
    end
    if type(any)=="boolean" then
        if any then return "true" end
        return "false"
    end
    if type(any)=="table" then
        local str = "{ "
        for k,v in pairs(any) do
            str=str..tostring(k).."->"..tostring(v).." "
        end
        return str.."}"
    end
    if type(any)=="number" then
        return ""..any
    end
    return "unkown" -- should never show
end
  
function shallow_copy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end
  
function orientation_to_direction(orientation)
  local direction = {x=0, y=0}
  if (orientation == e_orientation.right) then
    direction.x = 1
  elseif (orientation == e_orientation.left) then
    direction.x = -1
  elseif (orientation == e_orientation.up) then
    direction.y = -1
  elseif (orientation == e_orientation.down) then
    direction.y = 1
  end
  return direction
end


--Bullet
function update_bullet(_bullet)
  if (time() - _bullet.last_update_time > 1 / _bullet.speed) then
    _bullet.last_update_time = time()
    _bullet.pos.x += _bullet.direction.x
    _bullet.pos.y += _bullet.direction.y
  end
end

function draw_bullet(_bullet)
  render_sprite(_bullet.sprite_id, _bullet.pos.x, _bullet.pos.y)
end

function create_bullet(x, y, w, h, direction, speed, sprite_id)
  _bullet = {}
  _bullet.pos = {}
  _bullet.pos.x = x
  _bullet.pos.y = y
  _bullet.hitbox = {}
  _bullet.hitbox.x = 0 -- relative to pos
  _bullet.hitbox.y = 0
  _bullet.hitbox.w = w
  _bullet.hitbox.h = h
  _bullet.speed = speed -- pixels per second
  _bullet.direction = direction -- vector2
  _bullet.sprite_id = sprite_id
  _bullet.last_update_time = time()
  add(g_bullets, _bullet)
  return _bullet
end

function create_canon_bullet(x, y, direction)
  local speed = 1
  local hitbox_w = 1
  local hitbox_h = 1
  local sprite_id = 11
  create_bullet(x, y, hitbox_w, hitbox_h, direction, speed, sprite_id)
end

--building
function create_building(tile_x, tile_y, orientation, _building_type_id)
  local building = {}
    building.type = _building_type_id
    building.tile_pos = {}
      building.tile_pos.x = tile_x
      building.tile_pos.y = tile_y
    building.orientation = orientation
    
  if (building.type == building_type.canon) then
    building.sprite_id = 11
    building.cooldown = 1 -- time in sec
    building.activate = function (_building)
      bullet_pos = get_pixel_pos(_building.tile_pos.x,_building.tile_pos.y)
      direction = orientation_to_direction(_building.orientation)
      create_canon_bullet(bullet_pos.x, bullet_pos.y, direction)
      --create_canon_bullet(2, 3, {x=1, y=0})
    end
   else
    print("error : no building of this type : " .. _building_type_id)
   end
  
  g_map_buildings[building.tile_pos.x][building.tile_pos.y] = building
  return building
end

building_type = {}
building_type.canon = 1;

function updentity()
end

function draw_building(building)
  render_tiled_sprite(building.sprite_id, building.tile_pos.x, building.tile_pos.y, building.orientation)
end

__gfx__
00000000eeeeeeee33333333999999990000000000000000000000000000000000000000666666666000606066bb3ee380000000000000000000000000000000
00000000eeeeeeee333333339999999900000000000000000000000000000000000000006666600060606606666ee66e00000000000000000000000000000000
00700700eeeeeeee33333333999999991111111111111111111111111111111111111111666666666000606066bbe66e00000000000000000000000000000000
00077000eeeeeeee3333333399999999188bb171117171711717711171177711111111116333333333333336bbbb3ee300000000000000000000000000000000
00077000eeeeeeee3333333399999999188bb1717171117717171717171171111111111163333333333333361c11266200000000000000000000000000000000
00700700eeeeeeee33333333999999991cc99171717171717717171717171111111111116333333333333336ccc16ee600000000000000000000000000000000
00000000eeeeeeee33333333999999991cc991777771717117177111711777111111111163333333333333361c116ee600000000000000000000000000000000
00000000eeeeeeee333333339999999911111111111111111111111111111111111111116333333333333336c1c1266200000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000063333333333333360000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000063333333333333360000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000063333333333333360000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000063333333333333360000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000063333333333333360000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000063333333333333360000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000063333333333333360000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000066666666666666660000000000000000000000000000000000000000
__gff__
0000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0303030303030303010303030303030303010303030303030303010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0303030303030303010303030303030303010302020202020203010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0303030303030303010303020202020303010302020202020203010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0303030202030303010303020202020303010302020202020203010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0303030202030303010303020202020303010302020202020203010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0303030303030303010303020202020303010302020202020203010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0303030303030303010303030303030303010302020202020203010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0405060708080808010303030303030303010303030303030303010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
