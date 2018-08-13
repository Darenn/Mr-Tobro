pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
--lowrezjam
--by darenn keller

--Game
tile_size = 4
g_pixel_size = 64
g_row_tiles_count = 64 / tile_size 

deltatime = 1/30 -- because we're running at 30 fps


g_in_menu = false;

g_player = nil
g_spawner = nil
g_tobro_window = nil
g_money = 50

g_bullets = {}
g_enemies = {}
g_spawn_zones = {}


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
  g_menu = create_menu()
  g_spawner = create_spawner()
  g_tobro_window = create_tobro_window({x=6,y=6},4,4)
  create_level(g_spawner)
  music(1)
end

function _update()
    update_menu(g_menu)
    if (g_in_menu) then return end
    update_buildings()
    update_player(g_player)
    update_bullets()
    update_collisions()
    update_enemies()
    update_spawner(g_spawner)
end


function update_bullets()
  -- make a copy to allow removal from g_bullets
  local copy = shallow_copy(g_bullets)
  for bullet in all(copy) do
    update_bullet(bullet)
  end
end

function update_enemies()
  -- make a copy to allow removal from g_bullets
  local copy = shallow_copy(g_enemies)
  for e in all(copy) do
    update_enemy(e)
  end
end

function update_buildings()
  for x=0, g_row_tiles_count do
    for y=0, g_row_tiles_count do
      local building = g_map_buildings[x][y]
      if building != nil then 
        update_building(building)
      end
    end
  end
end

function update_collisions()
  local copyb = shallow_copy(g_bullets)
  for bullet in all(copyb) do
    local copye = shallow_copy(g_enemies)
    for e in all(copye) do
      local destroyed = false;
      if (collide(bullet, e)) then
        kill(e)
        destroyed = true;
      end
      if (not bullet.invicible and destroyed) then
        del(g_bullets, bullet)
      end
    end
  end
end

function _draw()
  cls()
  map(0, 0, 0, 0, 8, 8)
  draw_tobro_window(g_tobro_window)
  draw_player(g_player)
  draw_buildings()
  draw_spawn_zones()
  draw_bullets()
  draw_enemies()
  if (g_in_menu) then
    draw_menu(g_menu)
  end
  draw_ui()
end

function draw_bullets()
  for bullet in all(g_bullets) do
    draw_bullet(bullet)
  end
end

function draw_enemies()
  for e in all(g_enemies) do
    draw_enemy(e)
  end
end

function draw_spawn_zones()
  for e in all(g_spawn_zones) do
    draw_spawn_zone(e)
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
function render_tiled_sprite(n, tile_x, tile_y, orientation, n_vertical)
  orientation = orientation or e_orientation.right
  n_vertical = n_vertical or n
  
  local take_horizontal = orientation == e_orientation.left or orientation == e_orientation.right
  local take_vertical = orientation == e_orientation.up or orientation == e_orientation.down
  
  local flipx = orientation == e_orientation.left
  local flipy = orientation == e_orientation.down
  
  if (take_vertical) then 
    n = n_vertical
  end
  
  spr(n, tile_x * tile_size, tile_y * tile_size, 0.5, 0.5, flipx, flipy)
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
  local pressed = false
  if (btnp(0)) then
    pressed = true
    new_position.x -= 1
  elseif (btnp(1)) then
    pressed = true
    new_position.x += 1
  elseif (btnp(2)) then
    pressed = true
    new_position.y -= 1
  elseif (btnp(3)) then
    pressed = true
    new_position.y += 1
  end
  if (is_walkable(new_position)) then
    _player.pos = new_position
    if pressed then sfx(g_sound_manager.sfx_list.player_moves) end
  end
  pressed = false
end

function draw_player(_player)
  render_tiled_sprite(_player.sprite_id, _player.pos.x, _player.pos.y)
end


function create_player(x, y)
  _player = {}
    _player.pos = {}
    _player.pos.x = x -- x and y are tile positions
    _player.pos.y = y
    _player.sprite_id = 1
  return _player
end

--Collision
walkable_tile = 2

-- x and y are tile positions
function is_walkable(x, y)
  return mget(x / 2, y / 2) == walkable_tile
end

function is_walkable(position)
  --return mget(position.x / 2, position.y / 2) == walkable_tile
  local pos = {x = position.x / 2, y = position.y /2}
  return is_in_tobro_window(g_tobro_window, position)
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



--Bullet
function update_bullet(_bullet)
  if (time() - _bullet.last_update_time > 1 / _bullet.speed) then
    _bullet.last_update_time = time()
    _bullet.pos.x += _bullet.direction.x
    _bullet.pos.y += _bullet.direction.y
  end
  
  if time() - _bullet.birth_time > _bullet.lifetime then
   del(g_bullets, _bullet)
  end
end

function draw_bullet(_bullet)
  render_sprite(_bullet.sprite_id, _bullet.pos.x, _bullet.pos.y)
end

function create_bullet(x, y, w, h, direction, speed, sprite_id, lifetime, invicible)
    local _bullet = {}
  _bullet.pos = {}
  _bullet.pos.x = x
  _bullet.pos.y = y
  _bullet.hitbox = {}
  _bullet.hitbox.x = 0 -- relative to pos
  _bullet.hitbox.y = 0
  _bullet.hitbox.w = w
  _bullet.hitbox.h = h
  _bullet.lifetime = lifetime
  _bullet.invicible = invicible
  _bullet.speed = speed -- pixels per second
  _bullet.direction = direction -- vector2
  _bullet.sprite_id = sprite_id
  _bullet.last_update_time = time()
  _bullet.birth_time = time()
  add(g_bullets, _bullet)
  return _bullet
end

function create_canon_bullet(x, y, direction)
  local speed = 15
  local hitbox_w = 1
  local hitbox_h = 1
  local sprite_id = 9
  create_bullet(x, y, hitbox_w, hitbox_h, direction, speed, sprite_id, 99, false)
  sfx(g_sound_manager.sfx_list.canon_shoot)
end

function create_big_canon_bullet(x, y, direction)
  local speed = 15
  local hitbox_w = 4
  local hitbox_h = 4
  local sprite_id = 70
  create_bullet(x, y, hitbox_w, hitbox_h, direction, speed, sprite_id, 99, true)
  sfx(g_sound_manager.sfx_list.big_canon_shoot)
end

function create_explozeur_bullet(x, y, direction)
  local speed = 15
  local hitbox_w = 4
  local hitbox_h = 4
  local sprite_id = 70
  for _x=-3, 3 do
    for _y=-3, 3 do     
      create_bullet(x + _x, y + _y, hitbox_w, hitbox_h, direction, speed, sprite_id, 0.2, true)
    end
  end
  sfx(g_sound_manager.sfx_list.explozeur_shoot)
end

--Building
function create_building(tile_x, tile_y, orientation, _building_type_id)
  local building
  local build_info = g_buildings_info[_building_type_id]
  if (g_buildings_info[_building_type_id] != nil) then
    building = create_base_building(tile_x, tile_y, orientation, _building_type_id)
    building.horizontal_sprite_id = build_info.horizontal_sprite_id
    building.vertical_sprite_id = build_info.vertical_sprite_id
    building.hor_sprite_id_reload = build_info.hor_sprite_id_reload
    building.ver_sprite_id_reload =build_info.ver_sprite_id_reload
    building.cooldown = build_info.cooldown
    building.activate = build_info.activate
    building.price = build_info.price
  else
    print("error : no building of this type : " .. _building_type_id)
  end
  
  g_map_buildings[building.tile_pos.x][building.tile_pos.y] = building
  return building
end

building_type = {}
building_type.canon = 0
building_type.multiple_canon = 1
building_type.big_canon = 2
building_type.explozeur = 3

g_building_canon = {}
  g_building_canon.price = 5
  g_building_canon.horizontal_sprite_id = 2
  g_building_canon.vertical_sprite_id = 3
  g_building_canon.hor_sprite_id_reload = 10
  g_building_canon.ver_sprite_id_reload = 11
  g_building_canon.cooldown = 5 -- time in sec
  g_building_canon.activate = function (_building)
    if not _building.is_ready then return end
    on_activate(_building)
    local bullet_pos = get_pixel_pos(_building.tile_pos.x,_building.tile_pos.y)
    bullet_pos.x +=1
    bullet_pos.y +=1
    local direction = orientation_to_direction(_building.orientation)
    create_canon_bullet(bullet_pos.x, bullet_pos.y, direction)
  end
  
g_building_multiple_canon = {}
  g_building_multiple_canon.price = 20
  g_building_multiple_canon.horizontal_sprite_id = 6
  g_building_multiple_canon.vertical_sprite_id = 6
  g_building_multiple_canon.hor_sprite_id_reload = 12
  g_building_multiple_canon.ver_sprite_id_reload = 12
  g_building_multiple_canon.cooldown = 6 -- time in sec
  g_building_multiple_canon.activate = function (_building)
    if not _building.is_ready then return end
    on_activate(_building)
    -- create 4 bullets
    local bullet_pos = get_pixel_pos(_building.tile_pos.x,_building.tile_pos.y)
    bullet_pos.x +=1
    local direction = {x=0,y=-1}
    create_canon_bullet(bullet_pos.x, bullet_pos.y, direction)
    local bullet_pos = get_pixel_pos(_building.tile_pos.x,_building.tile_pos.y)
    bullet_pos.x +=2
    bullet_pos.y +=1
    local direction = {x=1,y=0}
    create_canon_bullet(bullet_pos.x, bullet_pos.y, direction)
    local bullet_pos = get_pixel_pos(_building.tile_pos.x,_building.tile_pos.y)
    bullet_pos.x +=1
    bullet_pos.y +=2
    local direction = {x=0,y=1}
    create_canon_bullet(bullet_pos.x, bullet_pos.y, direction)
    local bullet_pos = get_pixel_pos(_building.tile_pos.x,_building.tile_pos.y)
    bullet_pos.y +=1
    local direction = {x=-1,y=0}
    create_canon_bullet(bullet_pos.x, bullet_pos.y, direction)
  end
  
g_building_big_canon = {}
  g_building_big_canon.price = 50
  g_building_big_canon.horizontal_sprite_id = 4
  g_building_big_canon.vertical_sprite_id = 5
  g_building_big_canon.hor_sprite_id_reload = 13
  g_building_big_canon.ver_sprite_id_reload = 14
  g_building_big_canon.cooldown = 15 -- time in sec
  g_building_big_canon.activate = function (_building)
    if not _building.is_ready then return end
    on_activate(_building)
    local bullet_pos = get_pixel_pos(_building.tile_pos.x,_building.tile_pos.y)
    local direction = orientation_to_direction(_building.orientation)
    create_big_canon_bullet(bullet_pos.x, bullet_pos.y, direction)
  end
  
g_building_explozeur = {}
  g_building_explozeur.price = 50
  g_building_explozeur.horizontal_sprite_id = 7
  g_building_explozeur.vertical_sprite_id = 7
  g_building_explozeur.hor_sprite_id_reload = 15
  g_building_explozeur.ver_sprite_id_reload = 15
  g_building_explozeur.cooldown = 15 -- time in sec
  g_building_explozeur.activate = function (_building)
    if not _building.is_ready then return end
    on_activate(_building)
    local bullet_pos = get_pixel_pos(_building.tile_pos.x,_building.tile_pos.y)
    local direction = orientation_to_direction(_building.orientation)
    create_explozeur_bullet(bullet_pos.x, bullet_pos.y, direction)
  end
  
g_buildings_info = {}
g_buildings_info[building_type.canon] = g_building_canon
g_buildings_info[building_type.multiple_canon] = g_building_multiple_canon
g_buildings_info[building_type.big_canon] = g_building_big_canon
g_buildings_info[building_type.explozeur] = g_building_explozeur

-- all building are based on this, 
-- call this at start of each create building functions
function create_base_building(tile_x, tile_y, orientation, _building_type_id)
  local building = {}
    building.type = _building_type_id
    building.tile_pos = {}
      building.tile_pos.x = tile_x
      building.tile_pos.y = tile_y
    building.orientation = orientation
    building.is_ready = true
    building.reload_timer = 0
  return building
end

-- to call on activate functions
function on_activate(building)
  if not building.is_ready then
    sfx(g_sound_manager.sfx_list.building_reloading)
  end
  building.is_ready = false
  building.reload_timer = building.cooldown
end





function update_building(building)
  if not building.is_ready then
    building.reload_timer -= deltatime
  end
  if building.reload_timer <= 0 then
    building.is_ready = true
  end
end

function is_buildable(tile_position)
    local is_walkable = is_walkable(tile_position)
    local is_empty = g_map_buildings[tile_position.x][tile_position.y] == nil
    return is_walkable and is_empty
end

function draw_building(building)
  if building.is_ready then
    render_tiled_sprite(building.horizontal_sprite_id, building.tile_pos.x, 
    building.tile_pos.y, building.orientation, building.vertical_sprite_id)
  else
    render_tiled_sprite(building.hor_sprite_id_reload, building.tile_pos.x, 
    building.tile_pos.y, building.orientation, building.ver_sprite_id_reload)
  end
end

--Menu
function create_menu()
  local menu = {}
    menu.item_selected_index = 0
    menu.items = {-1, building_type.canon,building_type.multiple_canon, building_type.big_canon,
    building_type.explozeur}
    menu.highlighted_color = 12
    menu.highlighted_bad_color = 8
    menu.window_color = 1
    menu.between_icon_pixels = 2
    menu.top_bot_icon_pixels = 2
    menu.width_for_money = 15
    menu.window_height = #menu.items*tile_size + (#menu.items+1)*menu.between_icon_pixels
    menu.window_width = menu.top_bot_icon_pixels*2 + tile_size + menu.width_for_money
    menu.state = menu_states.building_selection
    menu.building_tile_pos = {x=6, y=6}
    menu.building_orientation = e_orientation.right
    return menu
end
  
function get_menu_selected_id(menu)
  return menu.items[menu.item_selected_index + 1]
end

function can_buy_selected_building(menu)
  if (get_menu_selected_id(menu) == -1) then return true end
  return g_buildings_info[get_menu_selected_id(menu)].price <= g_money
end
    
menu_states = {}
menu_states.building_selection = 1;
menu_states.building_location = 2;
menu_states.building_orientation = 3;



function update_menu(menu)
  if (btnp(5)) then
    on_menu_pressed(menu)
  end
  if (not g_in_menu) then return end
  if (btnp(4)) then
    on_activate_pressed(menu)  
  elseif (btnp(0)) then
    on_left_arrow_pressed(menu)
  elseif (btnp(1)) then
    on_right_arrow_pressed(menu)
  elseif (btnp(2)) then
    on_up_arrow_pressed(menu)
  elseif (btnp(3)) then
    on_down_arrow_pressed(menu)
  end
end

-- menu button is 5
-- activate button is 4

function on_activate_pressed(menu)
  if (is_in_selection(menu))then
    if can_buy_selected_building(menu) then
      sfx(g_sound_manager.sfx_list.validate_action)
      menu.state = menu_states.building_location
    else
      sfx(g_sound_manager.sfx_list.impossible_action)
    end
  elseif (is_in_location(menu)) then
    -- if we selected destroy
    if get_menu_selected_id(menu) == -1 then
      local building = g_map_buildings[menu.building_tile_pos.x][menu.building_tile_pos.y]
      if building != nil then
        sfx(g_sound_manager.sfx_list.building_destroyed)
        g_map_buildings[menu.building_tile_pos.x][menu.building_tile_pos.y] = nil
      else
        sfx(g_sound_manager.sfx_list.impossible_action)
      end
    elseif (is_buildable(menu.building_tile_pos)) then
      sfx(g_sound_manager.sfx_list.validate_action)
      menu.state = menu_states.building_orientation
    else
      sfx(g_sound_manager.sfx_list.impossible_action)
    end
    
  elseif (is_in_orientation(menu)) then
    sfx(g_sound_manager.sfx_list.validate_action)
    menu.state = menu_states.building_selection
    g_in_menu = false
    build_building(menu)
  end
end

function on_menu_pressed(menu)
  if (is_in_selection(menu))then
    g_in_menu = not g_in_menu
    if g_in_menu then sfx(g_sound_manager.sfx_list.open_menu)
    else sfx(g_sound_manager.sfx_list.close_menu) end
  elseif (is_in_location(menu)) then
    sfx(g_sound_manager.sfx_list.close_menu)
     menu.state = menu_states.building_selection
  elseif (is_in_orientation(menu)) then
     sfx(g_sound_manager.sfx_list.close_menu)
    menu.state = menu_states.building_location
  end
end
  

function on_left_arrow_pressed(menu)
  sfx(g_sound_manager.sfx_list.move_menu)
  if (is_in_location(menu)) then
    move_location_left(menu)
  elseif (is_in_orientation(menu)) then
    orientate_building_leftward(menu)
  end
end

function on_right_arrow_pressed(menu)
  sfx(g_sound_manager.sfx_list.move_menu)
  if (is_in_location(menu)) then
    move_location_right(menu)
  elseif (is_in_orientation(menu)) then
    orientate_building_rightward(menu)
  end
end

function on_up_arrow_pressed(menu)
  sfx(g_sound_manager.sfx_list.move_menu)
  if (is_in_selection(menu))then
    move_selection_up(menu)
  elseif (is_in_location(menu)) then
    move_location_up(menu)
  elseif (is_in_orientation(menu)) then
    orientate_building_upward(menu)
  end
end

function on_down_arrow_pressed(menu)
  sfx(g_sound_manager.sfx_list.move_menu)
  if (is_in_selection(menu))then
    move_selection_down(menu)
  elseif (is_in_location(menu)) then
    move_location_down(menu)
  elseif (is_in_orientation(menu)) then
    orientate_building_downward(menu)
  end
end
  
function build_building(menu)
  sfx(g_sound_manager.sfx_list.building_built)
  local id = get_menu_selected_id(menu)
  g_money -= g_buildings_info[get_menu_selected_id(menu)].price
  create_building(menu.building_tile_pos.x, menu.building_tile_pos.y, menu.building_orientation, id)
end

function move_selection_up(menu)
  menu.item_selected_index -= 1
  if (menu.item_selected_index < 0) then 
    menu.item_selected_index = 0 
  end
end

function move_selection_down(menu)
  menu.item_selected_index += 1
    if (menu.item_selected_index >= #menu.items-1) then 
      menu.item_selected_index = #menu.items-1
    end
end
  
function move_location_left(menu)
  menu.building_tile_pos.x -=1 
end

function move_location_right(menu)
  menu.building_tile_pos.x +=1
end

function move_location_up(menu)
  menu.building_tile_pos.y -=1
end

function move_location_down(menu)
  menu.building_tile_pos.y +=1
end

function orientate_building_upward(menu)
  menu.building_orientation = e_orientation.up
end

function orientate_building_downward(menu)
  menu.building_orientation = e_orientation.down
end

function orientate_building_leftward(menu)
  menu.building_orientation = e_orientation.left
end

function orientate_building_rightward(menu)
  menu.building_orientation = e_orientation.right
end

function is_in_selection(menu)
  return menu.state == menu_states.building_selection 
end

function is_in_location(menu)
  return menu.state == menu_states.building_location
end

function is_in_orientation(menu)
  return menu.state == menu_states.building_orientation
end




function draw_menu(menu)
  if(is_in_selection(menu))then
    draw_selection_menu(menu)
  elseif(is_in_location(menu)) then
    draw_location_menu(menu)
  elseif(is_in_orientation(menu))then
    draw_orientation_menu(menu)
  end
end
  
function draw_selection_menu(menu)
  -- draw the window background
  rectfill(0, 0, menu.window_width, menu.window_height, 6)  
  rectfill(0, 0, menu.window_width - 1, menu.window_height - 1, menu.window_color)
 
    
  -- draw the highlighted building (the selected one)
  local pos_x = menu.top_bot_icon_pixels - 1
  local pos_y = menu.between_icon_pixels*(menu.item_selected_index+1) + tile_size*menu.item_selected_index - 1
  local col = menu.highlighted_color
  if (not can_buy_selected_building(menu)) then col = menu.highlighted_bad_color end
  rectfill(pos_x, pos_y, pos_x + tile_size + 1 + menu.width_for_money , pos_y + tile_size + 1, col)
  
  -- draw the building icons 
  local pos_x = menu.between_icon_pixels
  for i=0, #menu.items - 1 do
    local pos_y = menu.top_bot_icon_pixels*(i+1) + tile_size*i
    local sprite_id
    if i == 0 then sprite_id = 69
    else
      building_id = menu.items[i + 1]
      sprite_id  = g_buildings_info[building_id].horizontal_sprite_id
    end
    render_sprite(sprite_id, pos_x, pos_y)    
  end
  
  -- draw the money and del
  local pos_x = 5 + menu.between_icon_pixels
  for i=0, #menu.items - 1 do
    local pos_y = menu.top_bot_icon_pixels*(i+1) + tile_size*i
    local sprite_id
    if i != 0 then 
      local building_id = menu.items[i + 1]
      local price  = g_buildings_info[building_id].price
      draw_money({x= pos_x, y=pos_y}, price)
    else
      --print("del", pos_x, pos_y, 7)
    end  
  end
  
end

function draw_location_menu(menu)
  if (is_buildable(menu.building_tile_pos)) then
    render_tiled_sprite(65, menu.building_tile_pos.x, menu.building_tile_pos.y)
  else
    render_tiled_sprite(66, menu.building_tile_pos.x, menu.building_tile_pos.y)
  end
  if get_menu_selected_id(menu) == -1 then
    local building = g_map_buildings[menu.building_tile_pos.x][menu.building_tile_pos.y]
    if building != nil then 
      render_tiled_sprite(65, menu.building_tile_pos.x, menu.building_tile_pos.y)
    else
      render_tiled_sprite(66, menu.building_tile_pos.x, menu.building_tile_pos.y)
    end
  end
end

function draw_orientation_menu(menu)
  local building = g_buildings_info[get_menu_selected_id(menu)]
  render_tiled_sprite(65, menu.building_tile_pos.x, menu.building_tile_pos.y)
  render_tiled_sprite(building.horizontal_sprite_id, menu.building_tile_pos.x, menu.building_tile_pos.y, menu.building_orientation, building.vertical_sprite_id)
end

function draw_money(pos, amount)
  spr(68, pos.x + 9, pos.y + 1)
  if amount > 9 then print(amount, pos.x, pos.y, 7)
  else print(amount, pos.x + 2, pos.y, 7) end
end

--Enemy
function instanciate_enemy(enemy_type, pos)
  local copy = shallow_copy(g_enemies_info[enemy_type])
  copy.pos = pos
  add(g_enemies, copy)
  return copy
end

function create_info_enemy(x, y, w, h, hp, speed, right_sprite_id, up_sprite_id)
  local enemy = {}
  enemy.pos = {}
  enemy.pos.x = x
  enemy.pos.y = y
  enemy.hitbox = {}
  enemy.hitbox.x = 0 -- relative to pos
  enemy.hitbox.y = 0
  enemy.hitbox.w = w
  enemy.hitbox.h = h
  enemy.direction = {x = 0, y = 0}
  enemy.hp = hp
  enemy.speed = speed -- pixels per second
  enemy.right_sprite_id = right_sprite_id
  enemy.up_sprite_id = up_sprite_id
  enemy.last_update_time = time()
  return enemy
end

function kill(enemy)          
  del(g_enemies, enemy)
  g_money += 1
  sfx(g_sound_manager.sfx_list.basic_enemy_dies)
end

g_enemy_type = {}
g_enemy_type.basic = 1

g_enemies_info = {}
g_enemies_info[g_enemy_type.basic] = create_info_enemy(0, 0, 4, 4, 1, 0.5, 8, 8)


function update_enemy(enemy)
  if (enemy.pos.x - 28 > 0) then
    enemy.direction.x = -1
  elseif (enemy.pos.x - 28 < 0) then
    enemy.direction.x = 1
  else
    enemy.direction.x = 0
  end
  
  if (enemy.pos.y - 28 > 0) then
    enemy.direction.y = -1
  elseif (enemy.pos.y - 28< 0) then
    enemy.direction.y = 1
  else
    enemy.direction.y = 0
  end
    
  if (time() - enemy.last_update_time > 1 / enemy.speed) then
    enemy.last_update_time = time()
    enemy.pos.x += enemy.direction.x
    enemy.pos.y += enemy.direction.y
  end
end

function draw_enemy(enemy)
  render_sprite(enemy.right_sprite_id, enemy.pos.x, enemy.pos.y)
end

--Spawner
function create_level(spawner)
  
  -- before start
  
  create_building(6, 7, e_orientation.left, building_type.canon) 
  -- at start
  
  local s1 = {x=0* tile_size, y=7* tile_size};
  spawn_zone(2, s1, spawner)
  spawn_enemy(3, g_enemy_type.basic, s1, spawner)
  
  local s2 = {x=7 * tile_size, y=0* tile_size}
  spawn_zone(5, s2, spawner)
  spawn_enemy(6, g_enemy_type.basic, s2, spawner)
  spawn_enemy(9, g_enemy_type.basic, s1, spawner)
  spawn_enemy(10, g_enemy_type.basic, s2, spawner)
  spawn_enemy(14, g_enemy_type.basic, s1, spawner)
  
  local s3 = {x=15* tile_size, y=7* tile_size}
  spawn_zone(10, s3, spawner)
  spawn_enemy(17, g_enemy_type.basic, s3, spawner)
  spawn_enemy(20, g_enemy_type.basic, s1, spawner)
  spawn_enemy(20, g_enemy_type.basic, s2, spawner)
  spawn_enemy(24, g_enemy_type.basic, s3, spawner)
  spawn_enemy(26, g_enemy_type.basic, s2, spawner)
  
end

function create_spawner()
  local spawner = {}
  spawner.enemies_to_spawn = {}
  spawner.zone_to_spawn = {}
  spawner.last_update_time = time()
  spawner.step = 0 -- one step per second
  return spawner
end

function spawn_enemy(spawn_step, enemy_type, pos, spawner)
  if (spawner.enemies_to_spawn[spawn_step]) == nil then
    spawner.enemies_to_spawn[spawn_step] = {}
  end
  add(spawner.enemies_to_spawn[spawn_step], {enemy_type = enemy_type, pos = {x=pos.x,y=pos.y}})
end

function spawn_zone(spawn_step, pos, spawner)
  if (spawner.zone_to_spawn[spawn_step]) == nil then
    spawner.zone_to_spawn[spawn_step] = {}
  end
  add(spawner.zone_to_spawn[spawn_step], {pos = pos})
end
  


function update_spawner(spawner)
  
  -- spawn every seconds
  if (time() - spawner.last_update_time > 1) then
    -- spawn enemies
    local spawn_table = spawner.enemies_to_spawn[spawner.step]
    if (spawn_table != nil) then
      for spawn_enemy_info in all(spawn_table) do
        instanciate_enemy(spawn_enemy_info.enemy_type, spawn_enemy_info.pos)
      end
    end
    
    -- spawn zones
    local spawn_table = spawner.zone_to_spawn[spawner.step]
    if (spawn_table != nil) then
      for zone in all(spawn_table) do
        create_spawn_zone(zone.pos)
      end
    end
    
    spawner.step += 1
    spawner.last_update_time = time()
  end
  
end

--SpawnZone
function create_spawn_zone(pos, sprite_id)
  sprite_id = sprite_id or 67
  local zone = {}
  zone.pos = pos
  zone.sprite_id = sprite_id
  add(g_spawn_zones, zone)
  sfx(g_sound_manager.sfx_list.spawn_zone_appears)
  return zone
end

function update_spawn_zone()
end

function draw_spawn_zone(zone)
  render_sprite(zone.sprite_id, zone.pos.x, zone.pos.y)
end

--TobroWindow
function create_tobro_window(tile_pos, tile_w, tile_h)
  tobro_window = {}
  tobro_window.tile_pos = tile_pos
  tobro_window.tile_w = tile_w
  tobro_window.tile_h = tile_h
  return tobro_window
end

function is_in_tobro_window(win, tile_pos)
  local p_poswh = {x=win.tile_pos.x+ win.tile_w, y=win.tile_pos.y + win.tile_h}
  if
      tile_pos.x >= win.tile_pos.x and tile_pos.x < p_poswh.x and
      tile_pos.y >= win.tile_pos.y and tile_pos.y < p_poswh.y
  then
      return true
  else
      return false
  end
end

function update_tobro_window()
end

function draw_tobro_window(win)
  local p_pos = get_pixel_pos(win.tile_pos.x, win.tile_pos.y)
  local p_poswh = get_pixel_pos(win.tile_pos.x+ win.tile_w, win.tile_pos.y + win.tile_h)
  rectfill(p_pos.x - 1, p_pos.y - 1, p_poswh.x, p_poswh.y, 6)
  rectfill(p_pos.x, p_pos.y, p_poswh.x - 1, p_poswh.y -1, 3)
end

--UI
function updateui()
end

function draw_ui()
  draw_price()
end


function draw_price()
  rectfill(48, 0, 64, 7, 6)
  rectfill(49, 0, 64, 6, 1)
  spr(68, 59, 2)
  if g_money > 9 then print(g_money, 50, 1, 7)
  else print(g_money, 52, 1, 7) end
  
end

--SoundManager
g_sound_manager = {}
g_sound_manager.sfx_list = {
  basic_enemy_dies = 1,
  quick_enemy_dies = 2,
  big_enemy_dies = 3,
  spawn_zone_appears = 4,
  get_coin = 5,
  player_moves = 6,
  open_menu = 7,
  close_menu = 8,
  move_menu = 9,
  validate_action = 10,
  impossible_action = 11,
  canon_shoot = 12,
  big_canon_shoot = 13,
  explozeur_shoot = 14,
  windows_xp_intro_lead = 15,
  windows_xp_outro_lead = 16,
  windows_xp_outro_bass = 17,
  windows_xp_intro_bass = 18,
  building_built = 19,
  building_reloading = 20,
  building_destroyed = 21
}

g_sound_manager.patterns = {
  window_xp_outro = 0,
  window_xp_intro = 1
  
}

__gfx__
000000001111000000000000050000000665000055550000656000000660000008080000e0000000000000000500000065600000066500005555000006600000
00000000e11e000006000000060000006ee500006ee600005e5000006ee60000082800000000000006000000060000005c5000006cc500006cc600006cc60000
00700700111100006e6500006e6000006ee500006ee60000656000006ee6000022222000000000006c6500006c600000656000006cc500006cc600006cc60000
000770001ee100000600000006000000066500000660000000000000066000000222000000000000060000000600000000000000066500000660000006600000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e0000000bbbb0000888800006d6c05700aa0000080080000eeee0000000000000000000000000000000000000000000000000000000000000000000000000000
00000000bbbb0000888800000bd6e576aaaa000008800000eeee0000000000000000000000000000000000000000000000000000000000000000000000000000
00000000bbbb00008888000008055570aaaa000008800000eeee0000000000000000000000000000000000000000000000000000000000000000000000000000
00000000bbbb0000888800000d8526070aa0000080080000eeee0000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000765ebe0c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000870b55c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000007d6b7ec0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000060700c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ccccccccccccccccccc777ccccccccccccccccccc777777777777777777777770000000000000000000000000000000000000000000000000000000000000000
cccccccccccccccccc777777ccccccccccccccccc777777777777777777777770000000000000000000000000000000000000000000000000000000000000000
cccccc7ccccccccccc7777777ccccc7ccccccccccc77777777777777777777770000000000000000000000000000000000000000000000000000000000000000
cccccc77cccccccccc777777777c77cccccccccccc777777777cccc7777777770000000000000000000000000000000000000000000000000000000000000000
c77cc77777cccccccc77777777777777cccc7ccccc77777777ccccc7777777770000000000000000000000000000000000000000000000000000000000000000
7c7777777777ccccc77777777777777777ccccccccccc7777ccc7777777777770000000000000000000000000000000000000000000000000000000000000000
cc7777777777777cc777777777777777777ccccccccccc7ccccc7777777777770000000000000000000000000000000000000000000000000000000000000000
cccc77777777777ccc777777777777c7777ccccccccccccccccc7777777777770000000000000000000000000000000000000000000000000000000000000000
cccccc777777777cccccc77777777cccccccccccccccccccccc7c77777cccccc0000000000000000000000000000000000000000000000000000000000000000
ccccccccccc777cccccccccc777777ccccccccccccccccccccc7c7777ccccccc0000000000000000000000000000000000000000000000000000000000000000
ccccccccccccccccccccccccc777777cccccccccccccccccccccccccccccc7cc0000000000000000000000000000000000000000000000000000000000000000
cc7ccccccccccccccccccccccc77777ccccccccccccccccccccccccccccccccc0000000000000000000000000000000000000000000000000000000000000000
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc0000000000000000000000000000000000000000000000000000000000000000
ccccccccccccccc77777cccccccccccccccccccccccccccccccccccccc77777c0000000000000000000000000000000000000000000000000000000000000000
ccccccccccccccc77777ccccccccccccccccccccccccccccccccccc77777777c0000000000000000000000000000000000000000000000000000000000000000
cccccc777ccccccc7777cccccccccccccccc7cccccccccccccccccc77777777c0000000000000000000000000000000000000000000000000000000000000000
cccccc777777ccccccccccccccccccccccccccccccccccccccccccc777777ccc0000000000000000000000000000000000000000000000000000000000000000
cccccc7777777cccccccccccccccccccccccccccccccccccccccccccccc77ccc0000000000000000000000000000000000000000000000000000000000000000
ccccccccc7777ccccccccccccccccccccccccccccccccccccccccccccccccccc0000000000000000000000000000000000000000000000000000000000000000
ccccccccccccccccccccccccccccccccc777cccccccccccccccccccccccccccc0000000000000000000000000000000000000000000000000000000000000000
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc0000000000000000000000000000000000000000000000000000000000000000
cccccccccccccccccccccccccccc777777cccccccccccccccccccccccccccccc0000000000000000000000000000000000000000000000000000000000000000
cccccccccccccccccccccccccc77777777cccccccccccc777ccccccccccccccc0000000000000000000000000000000000000000000000000000000000000000
cccccccccccccccccccccccccc777777777777ccccccc777777777cccccccccc0000000000000000000000000000000000000000000000000000000000000000
cccccccccccccccccccccccccc777777c77777ccccccc777777777cccccccccc0000000000000000000000000000000000000000000000000000000000000000
cccccccccccccccccccccccccccc7777ccccccccccccccc777777ccccccccccc0000000000000000000000000000000000000000000000000000000000000000
cccccccc7777cccccccccccccccccccccccccccccccccccccccccccccccccccc0000000000000000000000000000000000000000000000000000000000000000
ccccc7777777777ccccccccccccccc77777ccccccccccccccc777777ccc777cc0000000000000000000000000000000000000000000000000000000000000000
777777777777777cccccccccccc77777777777777ccccccc77777777777777cc0000000000000000000000000000000000000000000000000000000000000000
7777777777777777ccccccccccc77777ccc777777cccc77c77777777777777cc0000000000000000000000000000000000000000000000000000000000000000
7777777777777777777cccccccccccccccc7777777ccc77777777777cccccccc0000000000000000000000000000000000000000000000000000000000000000
77777777777777777777cccccccccccccccc777777ccc77777777777cccccccc0000000000000000000000000000000000000000000000000000000000000000
7777777777777777777777ccccccccccccccccccccccccccccccc77ccccccccc0000000000000000000000000000000000000000000000000000000000000000
77777777777777777777777ccccccccccccccccccccccccccc77777ccccccccc0000000000000000000000000000000000000000000000000000000000000000
7777bbbbbbbbbb7777777777cccccccccccc777cccccccccc777777ccccccccc0000000000000000000000000000000000000000000000000000000000000000
777bbbbbbbbbbb7777777777ccccccccc77c77777777cc777777777777c77ccc0000000000000000000000000000000000000000000000000000000000000000
bbbbbbbbbbbbbbbbbbb77bbcccccccccc77777777777777777777777777777770000000000000000000000000000000000000000000000000000000000000000
bbbbbbbbbbbbbbbbbbbbbbbbbbbbccccc77777777777777777777777777777770000000000000000000000000000000000000000000000000000000000000000
bbbbbbbbbbbbbbbbbbbbbbbbbbbbb3333333777777777777777c7777777777cc0000000000000000000000000000000000000000000000000000000000000000
bbbbbbbbbbbbbbbbbbbbbbbbbbbbb333333333333333cc77777cccc7117ccccc0000000000000000000000000000000000000000000000000000000000000000
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb333333333333c77cccccc11111c5c110000000000000000000000000000000000000000000000000000000000000000
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb3333333333333551115155110000000000000000000000000000000000000000000000000000000000000000
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb3333333333333335555110000000000000000000000000000000000000000000000000000000000000000
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb33333333333333330000000000000000000000000000000000000000000000000000000000000000
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb3333bbbbb33b0000000000000000000000000000000000000000000000000000000000000000
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb0000000000000000000000000000000000000000000000000000000000000000
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb0000000000000000000000000000000000000000000000000000000000000000
33bbbb33bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb0000000000000000000000000000000000000000000000000000000000000000
36666333333333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb0000000000000000000000000000000000000000000000000000000000000000
36cc6dd3333333333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb0000000000000000000000000000000000000000000000000000000000000000
36cc6dd33333333333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb0000000000000000000000000000000000000000000000000000000000000000
35663dd3335533333333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb0000000000000000000000000000000000000000000000000000000000000000
5555555555555553333333355bbbbb55bbbbbbbbbbbbbbbbbbbbbbbb555555550000000000000000000000000000000000000000000000000000000000000000
55533355553333555555555555555555555555555555555555555555533333330000000000000000000000000000000000000000000000000000000000000000
5333c333338333333333333333333333333333333333333333333333337333730000000000000000000000000000000000000000000000000000000000000000
333aac33397f333333333333333333333333333333333333333333333377bb730000000000000000000000000000000000000000000000000000000000000000
33accc33a777e3333333333333333333333333333333333333333333337b7b730000000000000000000000000000000000000000000000000000000000000000
3a3ca3333b7d33333333333333333333333333333333333333333333337bb7730000000000000000000000000000000000000000000000000000000000000000
3aa3cc3333c333333333333333333333333333333333333333333333333777330000000000000000000000000000000000000000000000000000000000000000
33333333333333333333333333333333333333333333333333333333333333330000000000000000000000000000000000000000000000000000000000000000
bbbbbbbbbb1111111111111111111111111111111111111111111111cccccccc0000000000000000000000000000000000000000000000000000000000000000
b83b77b7bb1111111111111111111111111111111111111111111111cc7c777c0000000000000000000000000000000000000000000000000000000000000000
bcab7b7b7b1111111111111111111111111111111111111111111111c7c77c7c0000000000000000000000000000000000000000000000000000000000000000
bbbbbbbbbb1111111111111111111111111111111111111111111111cccccccc0000000000000000000000000000000000000000000000000000000000000000
__gff__
0000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
8081828384858687000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
9091929394959697000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a0a1a2a3a4a5a6a7000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
b0b1b2b3b4b5b6b7000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c0c1c2c3c4c5c6c7000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
d0d1d2d3d4d5d6d7000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e0e1e2e3e4e5e6e7000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
f0f1f2f3f4f5f6f7000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00010000137502e750047501275038750317501a750297502a7500b750297500f7500f7502f75022750147501f7501c7502c75021750107502075000700207502c7502475000700287502f750327500070000700
000300001b0701b0601b0501b0401b030220702206022050220302202000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000002805028050280502b05028050250502405023050200501f0501e0501d0501c0501c0501c0501b05000000000000000000000000000000000000000000000000000000000000000000000000000000000
00040000226201d62038630126502763016650266201a6402d640376101c640306302d62018650156300d6402f60016600186002060029600126000e6003460031600136002a6002b60016600176003360024600
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010700000c01001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0001000016250182501c2501d2502025023250252502b2502f2503525038250001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
000100002f2502925026250212501d2501a25018250162501425011250102500e2500c2500a250082500825000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000002a05000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000900002a75033750007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
010a000037350000002b3500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00030000351503115032150301502f1502e1502d1002b100291002a10028100271002710026100261002610026100001003c1003a1003f1003510035100351000010000100001000010000100001000010000100
000100003561033610336603266031660306502f6402e6402d6402c6402b5302953028530275302653025530245302353022530225302152020520205201f5201f5101f5101e5101e6001d6001d6001d6001c600
00040000346703467033670326502e6302a63027630286302a6402c6402f6503065031660306602e6702a6702767024650216401a630136300a62002610026102360021600206001f6001e6001c6001b6001b600
0109000033040330403304033040330403304033040270402e0402e0402e0402e0402c0402c0402c0402c0402c0402c0402c0402c040330403304033040330402e0402e0402e0402e0402e0402e0402e0402e045
011d00002e04527045200452204022045000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011d00001403014030140301603016030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010900001103011030110301103011030110301103011030110301103011030110301403014030140301403014030140301403014030140301403014030140301603016030160301603016030160301603016035
000b000027040220402e0400000000000000000000030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200001227014230152201322012220102200f2200e2200c2100b21009210082100621004210022000120001200000000000000000000000000000000000000000000000000000000000000000000000000000
000300001f6601a640186301763015630146201362011620106200e6200c6200a6200762004610026100160000600006000060000600006000060000600006000060000600006000060000600006000060000600
__music__
04 10114344
04 0f124344

