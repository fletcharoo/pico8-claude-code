pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- bouncing ball animation

function _init()
 -- ball properties
 ball_x = 64
 ball_y = 20
 ball_vx = 2
 ball_vy = 0
 ball_radius = 4
 
 -- physics
 gravity = 0.3
 bounce_damping = 0.85
 
 -- colors
 ball_color = 8
 trail_color = 2
end

function _update()
 -- apply gravity
 ball_vy += gravity
 
 -- update position
 ball_x += ball_vx
 ball_y += ball_vy
 
 -- bounce off walls (left and right)
 if ball_x - ball_radius <= 0 or ball_x + ball_radius >= 127 then
  ball_vx = -ball_vx * bounce_damping
  ball_x = mid(ball_radius, ball_x, 127 - ball_radius)
 end
 
 -- bounce off floor and ceiling
 if ball_y - ball_radius <= 0 then
  ball_vy = -ball_vy * bounce_damping
  ball_y = ball_radius
 elseif ball_y + ball_radius >= 127 then
  ball_vy = -ball_vy * bounce_damping
  ball_y = 127 - ball_radius
  
  -- add small random bounce when hitting floor
  if abs(ball_vy) < 0.5 then
   ball_vy = -3 - rnd(2)
  end
 end
 
 -- apply friction
 ball_vx *= 0.999
end

function _draw()
 cls(0)
 
 -- draw shadow
 local shadow_y = 127
 local shadow_scale = 1 - (shadow_y - ball_y) / 100
 if shadow_scale > 0 then
  fillp(0b0101101001011010)
  circfill(ball_x, shadow_y, ball_radius * shadow_scale, 1)
  fillp()
 end
 
 -- draw ball with highlight
 circfill(ball_x, ball_y, ball_radius, ball_color)
 circfill(ball_x - 1, ball_y - 1, ball_radius/2, 7)
 
 -- draw floor line
 line(0, 127, 127, 127, 5)
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
