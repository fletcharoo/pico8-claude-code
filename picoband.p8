pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- minicruft: angband-inspired roguelike
-- by claude

-- constants
tile_size = 5
map_w = 25
map_h = 20
view_w = 25
view_h = 20

-- game state
state = "game"
depth = 0
player = {}
creatures = {}
items = {}
map_data = {}
messages = {}
turn = 0
inventory = {}
gold = 50

-- tile types
tile_floor = 0
tile_wall = 1
tile_door = 2
tile_stairs_up = 3
tile_stairs_down = 4
tile_shop_weapon = 5
tile_shop_potion = 6

-- creature types
creature_types = {
  {name="rat", char="r", hp=3, atk=1, def=0, col=5},
  {name="bat", char="b", hp=2, atk=1, def=0, col=2},
  {name="wolf", char="w", hp=5, atk=2, def=1, col=6}
}

function _init()
  init_player()
  generate_level()
  add_message("welcome to minicruft!")
end

function init_player()
  player = {
    x = 12,
    y = 10,
    hp = 20,
    max_hp = 20,
    atk = 3,
    def = 1,
    weapon = "dagger",
    weapon_bonus = 0
  }
  inventory = {
    potions = 2
  }
end

function generate_level()
  creatures = {}
  items = {}
  map_data = {}
  
  -- initialize map
  for x = 0, map_w-1 do
    map_data[x] = {}
    for y = 0, map_h-1 do
      map_data[x][y] = tile_wall
    end
  end
  
  if depth == 0 then
    generate_town()
  else
    generate_dungeon()
  end
end

function generate_town()
  -- create town square
  for x = 5, 19 do
    for y = 5, 14 do
      map_data[x][y] = tile_floor
    end
  end
  
  -- weapon shop
  map_data[7][7] = tile_shop_weapon
  
  -- potion shop
  map_data[17][7] = tile_shop_potion
  
  -- stairs down
  map_data[12][12] = tile_stairs_down
  
  -- place player
  player.x = 12
  player.y = 10
end

function generate_dungeon()
  local rooms = {}
  local num_rooms = 5 + rnd(3)
  
  for i = 1, num_rooms do
    local room = generate_room()
    if room then
      add(rooms, room)
      
      -- connect to previous room
      if #rooms > 1 then
        connect_rooms(rooms[#rooms-1], room)
      end
    end
  end
  
  -- place stairs
  if #rooms > 0 then
    local first_room = rooms[1]
    local last_room = rooms[#rooms]
    
    map_data[first_room.cx][first_room.cy] = tile_stairs_up
    map_data[last_room.cx][last_room.cy] = tile_stairs_down
    
    -- place player at up stairs
    player.x = first_room.cx
    player.y = first_room.cy
  end
  
  -- spawn creatures
  for i = 1, 3 + depth do
    spawn_creature()
  end
end

function generate_room()
  local tries = 50
  while tries > 0 do
    local w = 3 + flr(rnd(4))
    local h = 3 + flr(rnd(4))
    local x = 1 + flr(rnd(map_w - w - 2))
    local y = 1 + flr(rnd(map_h - h - 2))
    
    -- check if room fits
    local fits = true
    for rx = x-1, x+w+1 do
      for ry = y-1, y+h+1 do
        if rx >= 0 and rx < map_w and ry >= 0 and ry < map_h then
          if map_data[rx][ry] == tile_floor then
            fits = false
            break
          end
        end
      end
      if not fits then break end
    end
    
    if fits then
      -- carve room
      for rx = x, x+w do
        for ry = y, y+h do
          map_data[rx][ry] = tile_floor
        end
      end
      
      return {
        x = x,
        y = y,
        w = w,
        h = h,
        cx = x + flr(w/2),
        cy = y + flr(h/2)
      }
    end
    
    tries -= 1
  end
  return nil
end

function connect_rooms(room1, room2)
  local x1, y1 = room1.cx, room1.cy
  local x2, y2 = room2.cx, room2.cy
  
  -- horizontal then vertical
  if rnd(1) > 0.5 then
    for x = min(x1, x2), max(x1, x2) do
      map_data[x][y1] = tile_floor
    end
    for y = min(y1, y2), max(y1, y2) do
      map_data[x2][y] = tile_floor
    end
  else
    -- vertical then horizontal
    for y = min(y1, y2), max(y1, y2) do
      map_data[x1][y] = tile_floor
    end
    for x = min(x1, x2), max(x1, x2) do
      map_data[x][y2] = tile_floor
    end
  end
end

function spawn_creature()
  local tries = 50
  while tries > 0 do
    local x = flr(rnd(map_w))
    local y = flr(rnd(map_h))
    
    if map_data[x][y] == tile_floor and not get_creature_at(x, y) and 
       (x != player.x or y != player.y) then
      local type_idx = 1 + flr(rnd(min(#creature_types, 1 + depth/2)))
      local ctype = creature_types[type_idx]
      add(creatures, {
        x = x,
        y = y,
        hp = ctype.hp,
        max_hp = ctype.hp,
        atk = ctype.atk,
        def = ctype.def,
        char = ctype.char,
        name = ctype.name,
        col = ctype.col
      })
      return
    end
    tries -= 1
  end
end

function _update()
  if state == "game" then
    update_game()
  elseif state == "shop_weapon" then
    update_shop_weapon()
  elseif state == "shop_potion" then
    update_shop_potion()
  end
end

function update_game()
  local dx, dy = 0, 0
  
  if btnp(0) then dx = -1 end
  if btnp(1) then dx = 1 end
  if btnp(2) then dy = -1 end
  if btnp(3) then dy = 1 end
  
  if dx != 0 or dy != 0 then
    move_player(dx, dy)
  end
  
  -- use potion
  if btnp(4) then
    use_potion()
  end
end

function move_player(dx, dy)
  local nx = player.x + dx
  local ny = player.y + dy
  
  -- check bounds
  if nx < 0 or nx >= map_w or ny < 0 or ny >= map_h then
    return
  end
  
  -- check for creature
  local creature = get_creature_at(nx, ny)
  if creature then
    attack_creature(player, creature)
    move_creatures()
    turn += 1
    return
  end
  
  -- check tile
  local tile = map_data[nx][ny]
  if tile == tile_wall then
    return
  elseif tile == tile_stairs_down then
    depth += 1
    generate_level()
    add_message("you descend deeper...")
  elseif tile == tile_stairs_up then
    if depth > 0 then
      depth -= 1
      generate_level()
      add_message("you ascend...")
    end
  elseif tile == tile_shop_weapon then
    state = "shop_weapon"
    add_message("weapon shop - press z to buy")
  elseif tile == tile_shop_potion then
    state = "shop_potion"
    add_message("potion shop - press z to buy")
  else
    player.x = nx
    player.y = ny
    move_creatures()
    turn += 1
  end
end

function attack_creature(attacker, defender)
  local damage = max(1, attacker.atk - defender.def)
  defender.hp -= damage
  
  if attacker == player then
    add_message("you hit " .. defender.name .. " for " .. damage)
  else
    add_message(attacker.name .. " hits you for " .. damage)
  end
  
  if defender.hp <= 0 then
    if defender == player then
      add_message("you died! game over.")
      state = "gameover"
    else
      add_message(defender.name .. " dies!")
      del(creatures, defender)
      gold += 1 + flr(rnd(3))
    end
  end
end

function move_creatures()
  for c in all(creatures) do
    -- simple ai: move toward player if close
    local dist = abs(c.x - player.x) + abs(c.y - player.y)
    if dist <= 5 then
      local dx = sgn(player.x - c.x)
      local dy = sgn(player.y - c.y)
      
      -- try to move
      if rnd(1) > 0.5 then
        dx = 0
      else
        dy = 0
      end
      
      local nx = c.x + dx
      local ny = c.y + dy
      
      if nx == player.x and ny == player.y then
        attack_creature(c, player)
      elseif map_data[nx][ny] == tile_floor and not get_creature_at(nx, ny) then
        c.x = nx
        c.y = ny
      end
    end
  end
end

function get_creature_at(x, y)
  for c in all(creatures) do
    if c.x == x and c.y == y then
      return c
    end
  end
  return nil
end

function use_potion()
  if inventory.potions > 0 then
    local healed = min(10, player.max_hp - player.hp)
    player.hp = min(player.max_hp, player.hp + 10)
    inventory.potions -= 1
    add_message("healed " .. healed .. " hp!")
  else
    add_message("no potions!")
  end
end

function update_shop_weapon()
  if btnp(4) then
    if gold >= 20 then
      gold -= 20
      player.weapon_bonus += 1
      player.atk += 1
      add_message("weapon upgraded! +1 atk")
    else
      add_message("not enough gold! (need 20)")
    end
    state = "game"
  end
  if btnp(5) then
    state = "game"
  end
end

function update_shop_potion()
  if btnp(4) then
    if gold >= 5 then
      gold -= 5
      inventory.potions += 1
      add_message("bought potion!")
    else
      add_message("not enough gold! (need 5)")
    end
    state = "game"
  end
  if btnp(5) then
    state = "game"
  end
end

function add_message(msg)
  add(messages, msg)
  if #messages > 3 then
    del(messages, messages[1])
  end
end

function _draw()
  cls(0)
  
  if state == "gameover" then
    print("game over!", 40, 60, 8)
    print("you died on level " .. depth, 25, 70, 7)
    return
  end
  
  -- draw map
  for x = 0, map_w-1 do
    for y = 0, map_h-1 do
      local sx = x * tile_size
      local sy = y * tile_size
      local tile = map_data[x][y]
      
      if tile == tile_wall then
        print("#", sx, sy, 5)
      elseif tile == tile_floor then
        print(".", sx, sy, 1)
      elseif tile == tile_stairs_down then
        print(">", sx, sy, 7)
      elseif tile == tile_stairs_up then
        print("<", sx, sy, 7)
      elseif tile == tile_shop_weapon then
        print("w", sx, sy, 9)
      elseif tile == tile_shop_potion then
        print("p", sx, sy, 12)
      end
    end
  end
  
  -- draw creatures
  for c in all(creatures) do
    print(c.char, c.x * tile_size, c.y * tile_size, c.col)
  end
  
  -- draw player
  print("@", player.x * tile_size, player.y * tile_size, 7)
  
  -- draw ui
  print("hp:" .. player.hp .. "/" .. player.max_hp, 0, 105, 8)
  print("gold:" .. gold, 0, 111, 10)
  print("depth:" .. depth, 50, 105, 7)
  print("potions:" .. inventory.potions, 50, 111, 12)
  
  -- draw messages
  for i, msg in pairs(messages) do
    print(msg, 0, 117 + i * 6, 6)
  end
  
  -- shop ui
  if state == "shop_weapon" then
    rectfill(20, 40, 108, 70, 0)
    rect(20, 40, 108, 70, 7)
    print("weapon shop", 45, 45, 9)
    print("upgrade: 20g", 40, 52, 7)
    print("z:buy x:exit", 40, 60, 6)
  elseif state == "shop_potion" then
    rectfill(20, 40, 108, 70, 0)
    rect(20, 40, 108, 70, 7)
    print("potion shop", 45, 45, 12)
    print("potion: 5g", 45, 52, 7)
    print("z:buy x:exit", 40, 60, 6)
  end
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
