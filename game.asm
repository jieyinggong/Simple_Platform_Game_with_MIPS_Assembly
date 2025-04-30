#####################################################################
#
# CSCB58 Winter 2025 Assembly Final Project
#University of Toronto, Scarborough
#
# Student: Jieying Gong
#Student Number: 1009388066
#UTorID: gongjiey
#official email: jieying.gong@mail.utoronto.ca
#
# # Bitmap Display Configuration:
# - Unit width in pixels: 4 (update this as needed)
# - Unit height in pixels: 4 (update this as needed)
# - Display width in pixels: 512 (update this as needed)
# - Display height in pixels: 256 (update this as needed)
# - Base Address for Display: 0x10008000 ($gp)
#
# Which milestoneshave been reached in this submission?
# (See the assignment handout for descriptions of the milestones)
# - Milestone 1&2&3&a little part of 4 
#
# Which approved features have been implemented for milestone 3?
# (See the assignment handout for the list of additional features)
# 1. double jump
# 2. (fill in the feature, if any)
# 3. (fill in the feature, if any)
# ... (add more if necessary)
# # Link to video demonstration for final submission:
# - (insert YouTube / MyMedia / other URL here). Make sure we can view it!
# https://youtu.be/1TbqAkAvBWE
# # Are you OK with us sharing the video with people outside course staff? # -  no 
# # Any additional information that the TA needs to know:
# - (write here, if any)
#
#####################################################################
.eqv BASE_ADDRESS 0x10008000
.eqv WIDTH 128 
.eqv BULLET_TIME 500
#HEIGHT 64
.data 
player_coord: .word 5, 25 # the coordinate (x, y) indicates the position
# [0] platform/falling: 0 indicates on the platform, 1 indicates falling
# [1] direction: 1 indicates towards right, -1 indicates towards left
player_direction: .word 1
#jump state: [0] not jump, [1] jump,[2] double jump
player_jump_state: .word 0
player_platform_state: .word 1
score: .word 0 #the score that the player collected
platform_list: .word 0, 30, 30, 40, 18, 45, 43, 43, 55, 99, 30, 28 # platform struct: x,y,length
platform_count: .word 4
# coin position stored in the list
#max_coin = 4
# coin_pos struct: x, y，alived_flag
#if exist, alived_flag shows 1
coin_pos_list: .word  20, 26, 0, 85, 39, 0, 110, 26, 0, 75, 14, 0
coin_count: .word 0
# enemy position stored in the list 
# enemy_pos struct:  x, y, alived_flag
enemy_pos_list: .word 70, 39, 0, 100, 26, 0
# max enemy = 2
enemy_count: .word 0
total_time: .word 0
# player shooting avaliable state, player can only shoot one bullet at a time 
player_shooting_ava:.word 1 # 1 allows player to shoot
# a struct stores play's bullet's coordinator, direction direction and next move time (compared with total time)
player_bullet_state:.word 0, 0, 1, 0 #position_x, position_y, next_move_time

msg_left:   .asciiz "LEFT\n"
msg_right:  .asciiz "RIGHT\n"
msg_up:     .asciiz "UP\n"
msg_reset:  .asciiz "RESET\n"
msg_quit:   .asciiz "QUIT\n"
msg_collision: .asciiz "Collided at: "
msg_comma:     .asciiz ", "
msg_newline:   .asciiz "\n"

.globl main_start 
.text
main_start:
	li $t0, BASE_ADDRESS # $t0 stores the base address for display
	li $t1, 0x00000000 #black color 
	li $t2, 8192 #128*64
	#clear screen
clear_screen_loop:
	bnez $t2, clear_done
	sw $t1, 0($t0)
    	addi $t0, $t0, 4
   	addi $t2, $t2, -1
    	j clear_screen_loop
 clear_done:
 
 	#initialize
    	la $t0, enemy_count
   	li $t1, 0
    	sw $t1, 0($t0)

    	la $t0, total_time
    	li $t1, 0
    	sw $t1, 0($t0)

    	la $t0, coin_count
    	li $t1, 0
    	sw $t1, 0($t0)

    	la $t0, player_coord
    	li $t1, 5
    	sw $t1, 0($t0)
    	li $t1, 25
    	sw $t1, 4($t0)

    	la $t0, player_direction
    	li $t1, 1
    	sw $t1, 0($t0)

    	la $t0, player_jump_state
   	li $t1, 0
   	sw $t1, 0($t0)

    	la $t0, player_platform_state
   	li $t1, 1
    	sw $t1, 0($t0)

    	la $t0, score
    	li $t1, 0
    	sw $t1, 0($t0)   	   
	
	# draw the red region for fail condition in the bottom three row(row 61-63)
	li $a0, 0
	li $a1, 61
	jal address_of_pixel
	#get the address of the fail region top left pixel
	move $t0, $v0
	li $t4, 0
	li $t1, 0xff0000
start_draw_fail_region_loop:
	beq $t4, WIDTH, draw_fail_region_loop_end
	sw $t1, 0($t0)
	sw $t1, 512($t0)
	sw $t1, 1024($t0)
	addi $t0, $t0, 4 # move to next column
	addi $t4, $t4, 1
	j start_draw_fail_region_loop
draw_fail_region_loop_end:
 	#draw all the platforms
 	jal draw_all_platforms
 	
 	#draw player
 	la $t0, player_coord
 	lw $a0, 0($t0)
	lw $a1, 4($t0)
 	jal draw_player_to_right
 
main_loop:
generate_objects:
	#generate coins if there is no coins
	la $t0, coin_count
	lw $t1, 0($t0)
	beq $t1, 0, generate_all_coins
	#generate enemies if there is no enemy
	la $t0, enemy_count
	lw $t1, 0($t0)
	beq $t1, 0, generate_all_enemies
	
	la   $t0, player_coord
	lw   $t8, 0($t0)    # $t8 = x of player pos
	lw   $t9, 4($t0)    # $t9 = y of player pos
	
	#the row under the player's bottom row
	addi $t0, $t9, 5
	
	#check if reach to the read fail region
	bge $t0, 61, game_over
	
	#player's top right x: player_x + 2
	addi $t1, $t8, 2
    	
    	la   $t2, platform_list      # address to platform_list
    	lw   $t3, platform_count     # number of platform
    	li   $t4, 0                  # index
    	li   $t5, 0                  # platform_result  (set to 1 if on platform)
    	
check_on_platform:    	
	beq  $t4, $t3, end_platform_check     # if index == num of platform, end loop

    	# load platform x, y, length
   	lw   $t6, 0($t2)    # platform_x
   	lw   $t7, 4($t2)    # platform_y
    	lw   $s0, 8($t2)    # platform_length

   	# check verticaly, if plat_y == player_bottom_row + 1 stored in $t0
   	bne  $t7, $t0, skip_this_platform

    	# check horizontaly:
    	# if player_x > platform_x + length - 1, skip
    	add  $s2, $t6, $s0      # plat_x + length
    	addi $s2, $s2, -1
    	bgt $t8, $s2, skip_this_platform
    	# if player_x + 2 < platform_x, skip
    	blt  $t1, $t6, skip_this_platform

    	# is on the platform
    	li   $t5, 1
    	j    end_platform_check

skip_this_platform:
    	addi $t2, $t2, 12   # move to next platform (3 * 4bytes)
   	addi $t4, $t4, 1
    	j    check_on_platform

end_platform_check:
    	la   $t0, player_platform_state
    	sw   $t5, 0($t0)    # save result (1 or 0)
    	
    	# if not on the platform, falling 
    	bne $t5, 1, player_falling
    	la $t0, player_jump_state
        li $t1, 0 # set player_jump_state = 0
        sw $t1, 0($t0)    
    	
object_collision:
	#check coin collision
	li $a0 3 #coin width
	li $a1 4 # coin height
	la $t0, coin_pos_list #coin list address
	la $a2, 0($t0)
	li $a3, 4 #max number of coin
	jal check_collision
	
	move $t0, $v0
	beq $t0, 1, coin_collect
	
	#check enemy cllision
	li $a0 4 #enemy width
	li $a1 4 # enemy height
	la $t0, enemy_pos_list #enemy list address
	la $a2, 0($t0)
	li $a3, 2 #max number of enemy
	jal check_collision
	
	move $t0, $v0
	beq $t0, 1, enemy_touch	
	j read_from_keyboard
	
coin_collect:	
	move $s1, $v1
	li $t2, 0
	sw $t2, 8($s1) #set the alived flag of this object = 0
	
	lw $a0, 0($s1)
	lw $a1, 4($s1)
	jal erase_coin
	
	#coin_count - 1
	la $t0, coin_count
	lw $t1, 0($t0)
	addi $t1, $t1, -1
	sw $t1, 0($t0)
	
	# score + 1
	la $t3, score
	lw $t4, 0($t3)
	addi $t4, $t4, 1
	sw $t4, 0($t3)
	
	li $v0, 4
   	la $a0, msg_comma
    	syscall	
	
	move $a0, $t4     # score
    	li $v0, 1
    	syscall
    	
    	li $v0, 4
    	la $a0, msg_newline
    	syscall
    	
    	j read_from_keyboard

enemy_touch:	
	move $s1, $v1
	li $t2, 0
	sw $t2, 8($s1) #set the alived flag of this object = 0
	
	lw $a0, 0($s1)
	lw $a1, 4($s1)
	jal erase_enemy
	
	#enemy_count - 1
	la $t0, enemy_count
	lw $t1, 0($t0)
	addi $t1, $t1, -1
	sw $t1, 0($t0)
	
	# score - 1
	la $t3, score
	lw $t4, 0($t3)
	beqz $t4, read_from_keyboard
	addi $t4, $t4, -1
	sw $t4, 0($t3)
	
	li $v0, 4
   	la $a0, msg_comma
    	syscall	
	
	lw $a0, 0($t3)     # score
    	li $v0, 1
    	syscall
    	
    	li $v0, 4
    	la $a0, msg_newline
    	syscall
    	
    	j read_from_keyboard
	
    	#read from keyboard
read_from_keyboard:
        li $t0, 0xffff0000       
        li $t1, 0xffff0004       

     	lw $t2, 0($t0)           # check if there is a key
    	beqz $t2, no_key         # if no key, jump to no_key

    	lw $t3, 0($t1)           # read key
   
    	la $t0, player_coord
 	lw $a0, 0($t0)
	lw $a1, 4($t0)
	
    	la $t1, player_direction
    	lw $a2, 0($t1)
    	
   	li $t4, 0x61             # 'a'
   	beq $t3, $t4, move_to_left
   	li $t4, 0x64             # 'd'
        beq $t3, $t4, move_to_right
   	li $t4, 0x77             # 'w'
  	beq $t3, $t4, player_jump	
  	li $t4, 0x72             # 'r'
   	beq $t3, $t4, key_reset
  	li $t4, 0x71             # 'q'
   	beq $t3, $t4, key_quit
    		
check_score: 	
   	#check and update score
   	la $t0, score
   	lw $s1, 0($t0)
   	move $a0, $s1
   	jal draw_score_bar
   	
   	bge $s1, 3, you_won

main_loop_wait:
	# add total time
	la $t0, total_time
	lw $t1, 0($t0)
	addi $t1, $t1, 100
	sw $t1, 0($t0)
	
   	li $v0, 32
	li $a0, 100     # wait 100ms
	syscall

no_key:
    j main_loop              # if no key, continue loop

# if press 'a', the player would move to left, (x - 1)
# $a0 and $a1 passes player's current coordinator(x, y) and $a2 passes player's direction
move_to_left:
       la $t1, player_direction
       li $t2, -1
       sw $t2, 0($t1)       
               
       #erase the origin player
       jal erase_player
       #move 2 unit to the left 
       addi $a0, $a0, -2
       jal draw_player_to_left
       #update player's position
       la $t0, player_coord
       lw $t1, 0($t0) #update x
       addi $t1, $t1, -2
       sw $t1, 0($t0)
    
    	j check_score

move_to_right:
       #update player_direction
       la $t1, player_direction
       li $t2, 1
       sw $t2, 0($t1)       
               
       #erase the origin player
       jal erase_player
       #move 2 unit to the right
       addi $a0, $a0, 2
       jal draw_player_to_right
       #update player's position
       la $t0, player_coord
       lw $t1, 0($t0) #update x
       addi $t1, $t1, 2
       sw $t1, 0($t0)
    
    	j  check_score

player_jump:
       la $t0, player_jump_state
       lw $t1, 0($t0)
       
       beq $t1, 2, check_score # can't jump twice if state is double jump
       
       addi $t1, $t1, 1
       sw $t1, 0($t0)       
       #erase the origin player
       jal erase_player
       
       addi $sp, $sp, -8
       sw $a0, 0($sp)
       sw $a1, 4($sp)
       #redraw all the platforms
       jal draw_all_platforms
       lw $a0, 0($sp)
       lw $a1, 4($sp)
       addi $sp, $sp, 8
       
       la $t2, player_direction
       lw $t3, 0($t2)
       #move 15 units up
       addi $a1, $a1, -15
       beq $t3, 1, if_jump_towards_right
       jal draw_player_to_left
       j end_jump
       if_jump_towards_right:
       jal draw_player_to_right 
       end_jump:
       #update player's position
       la $t0, player_coord
       lw $t1, 4($t0) #update y
       addi $t1, $t1, -15
       sw $t1, 4($t0)
    
       j  check_score
    
player_falling:      
	la $t0, player_coord
 	lw $a0, 0($t0)
	lw $a1, 4($t0)
	
       #erase the origin player
       jal erase_player
       
       addi $sp, $sp, -8
       sw $a0, 0($sp)
       sw $a1, 4($sp)
       #redraw all the platforms
       jal draw_all_platforms
       lw $a0, 0($sp)
       lw $a1, 4($sp)
       addi $sp, $sp, 8
       
       la $t2, player_direction
       lw $t3, 0($t2)
       #move 1 units down
       addi $a1, $a1, 1
       beq $t3, 1, if_fall_towards_right #check player direction
       jal draw_player_to_left
       j end_falling
       if_fall_towards_right:
       jal draw_player_to_right 
       end_falling:
       #update player's position
       la $t0, player_coord
       lw $t1, 4($t0)  #update y
       addi $t1, $t1, 1
       sw $t1, 4($t0)
       
       # add total time
	la $t0, total_time
	lw $t1, 0($t0)
	addi $t1, $t1, 50
	sw $t1, 0($t0)
	
       li $v0, 32
	li $a0, 50     # wait 50ms
	syscall
       
       j object_collision	

key_reset:
    	li $v0, 4
   	la $a0, msg_reset
   	syscall
   	
   	la $t0, player_coord
 	lw $a0, 0($t0)
	lw $a1, 4($t0)
	jal erase_player
	
    	j main_start

key_quit:
    	li $v0, 4
    	la $a0, msg_quit
    	syscall
    	j program_end   
 	
 program_end:
	li $v0, 10 # terminate the program gracefully
	syscall 

address_of_pixel: #recievie the coordinate of a pixel, a0 passes x and a1 passes y, return the address
	li $t0, BASE_ADDRESS
	sll $t1, $a1, 7 # t4 stores y*width
	add $t1, $t1, $a0  # t4 stores y*width + x
	sll $t1, $t1, 2 #t4 stores (y * width + x)* 4
	add $t1, $t1, $t0 # which is our target address
	move $v0, $t1
	jr $ra
	
#draw a platform with its top left coordinate (x, y)sotred $a0,$a1 and the length stored in $a2
#return nothing	
draw_platform: 
	#store $ra
	addi $sp, $sp, -4
    	sw   $ra, 0($sp)
    	move $t3, $a2 #get the platform length from $a2
	jal address_of_pixel 
	move $t0, $v0 #get the address of pixel at the top left
   	
	li $t1, 0x00808080  #t1 stores the grey coulor code
	li $t2, 0 # column flag for drawing
start_draw_platform_loop:
	beq $t2, $t3, draw_platform_loop_end
	sw $t1, 0($t0)
	sw $t1, 512($t0)
	addi $t0, $t0, 4 # move to next column
	addi $t2, $t2, 1
	j start_draw_platform_loop
 draw_platform_loop_end:
 	#restore $ra
	lw   $ra, 0($sp)
    	addi $sp, $sp, 4
    	jr $ra
    	
draw_all_platforms:
    	addi $sp, $sp, -4
    	sw   $ra, 0($sp)

   	la  $t0, platform_list    
    	lw  $t1, platform_count  
    	li  $t2, 0               

draw_all_platforms_loop:
    	beq  $t2, $t1, draw_all_platforms_end
    	#store $t0, $t2
	addi $sp, $sp, -12
	sw $t0, 0($sp)
	sw $t1, 4($sp)
	sw $t2, 8($sp)
   	 # get position and length from list
    	lw   $a0, 0($t0)     # x
    	lw   $a1, 4($t0)     # y
    	lw   $a2, 8($t0)     # length

    	# draw_platform
    	jal  draw_platform
    	
    	#restore $t0, $t2
    	lw $t0, 0($sp)
    	lw $t1, 4($sp)
	lw $t2, 8($sp)
	addi $sp, $sp, 12

    	# draw next platfrom
    	addi $t0, $t0, 12
    	addi $t2, $t2, 1
    	
    	j    draw_all_platforms_loop

draw_all_platforms_end:
    	lw   $ra, 0($sp)
   	addi $sp, $sp, 4
  	jr   $ra
    	
#check left and right boundary depend on its width and coordinator
#$a0 passes x, $a1 passes y as coordinator, $a2 passes width	
#return the coordinator (x,y) limited in the boundary
check_boundary_for_player:
	la $t0, player_coord
	#check left bounday 
	bge  $a0, 0,check_right_boundary
    	li $a0, 0
    	sw $a0, 0($t0)
    	j check_upper_boundary
    	
    	check_right_boundary: 
    	addi $a2, $a2, -1
    	add $t1, $a0, $a2
    	blt  $t1, WIDTH, check_upper_boundary
    	li $a0, 125
    	sw $a0, 0($t0)
    	
    	check_upper_boundary:
    	bge  $a1, 0, check_boundary_end
    	li $a1, 0
    	sw $a1, 4($t0)
    		
    	check_boundary_end:
    	move $v0, $a0
    	move $v1, $a1
    	jr $ra
    	
#draw the player(size 3 x 5) with its top left coordinate (x, y)stored in $a0, $a1    	
draw_player_to_right:
	#store $ra
	addi $sp, $sp, -4
    	sw   $ra, 0($sp)
    	
    	li $a2, 3
    	jal check_boundary_for_player
    	move $a0, $v0
    	move $a1, $v1
    	
	jal address_of_pixel 
	move $t0, $v0  #get the address of pixel at the top left
	
	li $t1,0x000000ff
	sw $t1, 0($t0) #row 1
	addi $t0, $t0, 512 #move to next row
	sw $t1, 0($t0)#row 2
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	addi $t0, $t0, 512 #move to next row
	sw $t1, 0($t0) #row3
	sw $t1, 4($t0)
	addi $t0, $t0, 512 #move to next row
	sw $t1, 0($t0)#row 4
	sw $t1, 4($t0)
	addi $t0, $t0, 512 #move to next row
	sw $t1, 0($t0)#row 5
	sw $t1, 8($t0)
	
	lw   $ra, 0($sp)
    	addi $sp, $sp, 4
    	jr $ra
    	
draw_player_to_left:
	#store $ra
	addi $sp, $sp, -4
    	sw   $ra, 0($sp)
    	
    	li $a2, 3
    	jal check_boundary_for_player
    	move $a0, $v0
    	move $a1, $v1
    	
	jal address_of_pixel 
	move $t0, $v0  #get the address of pixel at the top left
	
	li $t1,0x000000ff
	sw $t1, 8($t0) #row 1
	addi $t0, $t0, 512 #move to next row
	sw $t1, 0($t0)#row 2
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	addi $t0, $t0, 512 #move to next row
	sw $t1, 8($t0) #row3
	sw $t1, 4($t0)
	addi $t0, $t0, 512 #move to next row
	sw $t1, 8($t0)#row 4
	sw $t1, 4($t0)
	addi $t0, $t0, 512 #move to next row
	sw $t1, 0($t0)#row 5
	sw $t1, 8($t0)
	
	lw   $ra, 0($sp)
    	addi $sp, $sp, 4
    	jr $ra

erase_player:
	addi $sp, $sp, -4
    	sw   $ra, 0($sp)
    	
    	li $a2, 3
    	jal check_boundary_for_player
    	move $a0, $v0
    	move $a1, $v1
    	
	jal address_of_pixel 
	move $t0, $v0  #get the address of pixel at the top left
	li $t1, 0x00000000 #t1 stores the black coulor code
	li $t2, 0 # column flag for drawing
start_erase_player_loop:	
	beq  $t2, 5, finish_erase_player_loop   
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	addi $t0, $t0, 512 #move to next row
	addi $t2, $t2, 1	
	j start_erase_player_loop
finish_erase_player_loop:	
	lw   $ra, 0($sp)
    	addi $sp, $sp, 4
    	jr $ra			
		 
#draw a coin(size 3 x 3) with its top left coordinate (x, y)stored in $a0, $a1, return nothing	
draw_coin:  
	#store $ra
	addi $sp, $sp, -4
    	sw   $ra, 0($sp)
	jal address_of_pixel 
	move $t0, $v0 #get the address of pixel at the top left of the coin
   	
	li $t1, 0xffff00 #t1 stores the yellow coulor code
	li $t2, 0 # column flag for drawing
	#draw coin in rows
start_draw_coin_loop:	
	beq  $t2, 3, finish_draw_coin_loop   
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	addi $t0, $t0, 512 #move to next row
	addi $t2, $t2, 1	
	j start_draw_coin_loop
finish_draw_coin_loop:	
	#restore $ra
	lw   $ra, 0($sp)
    	addi $sp, $sp, 4
    	jr $ra	
 
# $a0,a1 pass the coordinate x, y
erase_coin:
	addi $sp, $sp, -4
    	sw   $ra, 0($sp)
    	
    	jal address_of_pixel 
	move $t0, $v0  #get the address of pixel at the top left
	li $t1, 0x00000000 #t1 stores the black coulor code
	li $t2, 0 # column flag for drawing
	
start_erase_coin_loop:	
	beq  $t2, 3, finish_erase_coin_loop   
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	addi $t0, $t0, 512 # move to next row
	addi $t2, $t2, 1	
	j start_erase_coin_loop
	
finish_erase_coin_loop:
	lw   $ra, 0($sp)
    	addi $sp, $sp, 4	
    	jr $ra		
	
#draw a enemy(size 4 x 4) with its top left coordinate (x, y)stored in $a0, $a1, return nothing	
draw_enemy:  
	#store $ra
	addi $sp, $sp, -4
    	sw   $ra, 0($sp)
	jal address_of_pixel 
	move $t0, $v0 #get the address of pixel at the top left of the coin
   	
	li $t1, 0x00ff00ff #t1 stores the yellow coulor code
	li $t2, 0 # column flag for drawing
	#draw coin in rows
	
start_draw_enemy_loop:	
	beq  $t2, 3, finish_draw_enemy_loop   
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	addi $t0, $t0, 512 #move to next row
	addi $t2, $t2, 1	
	j start_draw_enemy_loop
	
finish_draw_enemy_loop:	
	sw $t1, 4($t0) # draw row 4
	sw $t1, 8($t0)
	#restore $ra
	lw   $ra, 0($sp)
    	addi $sp, $sp, 4
    	jr $ra
 
   	# $a0,a1 pass the coordinate x, y
erase_enemy:
	addi $sp, $sp, -4
    	sw   $ra, 0($sp)
    	
    	jal address_of_pixel 
	move $t0, $v0  #get the address of pixel at the top left
	li $t1, 0x00000000 #t1 stores the black coulor code
	li $t2, 0 # column flag for drawing
start_erase_enemy_loop:	
	beq  $t2, 4, finish_erase_enemy_loop   
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	addi $t0, $t0, 512 #move to next row
	addi $t2, $t2, 1	
	j start_erase_enemy_loop
finish_erase_enemy_loop:
	lw   $ra, 0($sp)
    	addi $sp, $sp, 4	
    	jr $ra	 
    	 	
generate_all_coins: 
   	la  $t0, coin_pos_list   
    	li  $t1, 4 
    	li  $t2, 0               

generate_all_coins_loop:
    	beq  $t2, $t1, generate_all_coins_end
    	#store $t0, $t2
	addi $sp, $sp, -12
	sw $t0, 0($sp)
	sw $t1, 4($sp)
	sw $t2, 8($sp)
    	
    	#restore x and y of coin
    	lw $t3, 0($t0)
    	lw $t4, 4($t0)
	
	#set alived_flag
	li $t5, 1
	sw $t5, 8($t0)
	
	#draw coin
	move $a0, $t3
	move $a1, $t4
	jal draw_coin
	
	#restore all and free stack space
    	lw $t0, 0($sp)
    	lw $t1, 4($sp)
	lw $t2, 8($sp)
	addi $sp, $sp, 12
   
    	addi $t0, $t0, 12
    	addi $t2, $t2, 1
    	
    	j generate_all_coins_loop

generate_all_coins_end:
	la $t0, coin_count
	lw $t1, 0($t0)
	li $t1, 4
	sw $t1, 0($t0)
    	lw $ra, 0($sp)
   	addi $sp, $sp, 4
  	j generate_objects
  	
	
generate_all_enemies: 
   	la  $t0, enemy_pos_list   
    	li  $t1, 2
    	li  $t2, 0               

generate_all_enemies_loop:
    	beq  $t2, $t1, generate_all_enemies_end
    	#store $t0, $t2
	addi $sp, $sp, -12
	sw $t0, 0($sp)
	sw $t1, 4($sp)
	sw $t2, 8($sp)
    	
    	#restore x and y of coin
    	lw $t3, 0($t0)
    	lw $t4, 4($t0)
    	
    	#set alived_flag
	li $t5, 1
	sw $t5, 8($t0)
	
	#draw enemy
	move $a0, $t3
	move $a1, $t4
	jal draw_enemy
	
	#restore all and free stack space
    	lw $t0, 0($sp)
    	lw $t1, 4($sp)
	lw $t2, 8($sp)
	addi $sp, $sp, 12
   
    	addi $t0, $t0, 12
    	addi $t2, $t2, 1
    	
    	j generate_all_enemies_loop

generate_all_enemies_end:
	la $t0, enemy_count
	lw $t1, 0($t0)
	li $t1, 2
	sw $t1, 0($t0)
    	lw $ra, 0($sp)
   	addi $sp, $sp, 4
  	j generate_objects
   
# $a0 passes the width of the object, #a1 passes the size of the object
# $a2 passes the the address of the object list, #a3 passes the max number of the object
# the return values: $v0 returns if there is a touch(0 shows no touch, 1 shows has a touch),
# $v1 returns the address of the touched object in the list if there is a touch
# object should have a same structure as: x, y, alived_flag
check_collision:
	la $t0, player_coord
	lw $t1, 0($t0) #player's x_position
	lw $t2, 4($t0) #player's y_position

	li  $t0, 0 #index
	li  $v0, 0 #default case with no touch
	
check_collision_loop:	
	beq  $t0, $a3, check_collision_end # if index == max number, end loop
	mul  $t4, $t0, 12
    	add  $t5, $a2, $t4 # get the address of ith object
    	
    	lw   $t6, 0($t5) # object.x
    	lw   $t7, 4($t5) # object.y
    	lw   $t8, 8($t5) # object alive_flag
    	beqz $t8, skip_check_collision # jump the objects that are not alived
    	
    	#check bottom contact
    	#get the line below the player bottom line
    	addi $t8, $t2, 5
   	beq  $t7, $t8, collision_check_bottom_x
    	j    collision_check_left
    	
collision_check_bottom_x:
	addi $t9, $t1, 3        # right side of the player: player.x + 3
    	add  $t8, $t6, $a0      # right side of the object: object.x + object.width
    	# check if right side of player =< left side of object
   	ble  $t9, $t6, collision_check_left
   	# check if right side of object =< left side of player
    	ble  $t8, $t1, collision_check_left
    	# if overlap, right side of player > left side of object && left side of player < right side of object
   	j exist_touch_return

collision_check_left:
	add  $t8, $t6, $a0      # right side of the object: object.x + object.width
   	beq  $t8, $t1, collision_check_left_y # if right side of object + 1 == left side of player
    	j    collision_check_right

collision_check_left_y:
	addi $t9, $t2, 5       # bottom line of player.y + 5
   	add  $t8, $t7, $a1      # bottom line of object.y + object.height
   	# if top of player >= bottom line of object
   	ble  $t8, $t2, collision_check_right
   	# if top of object >= bottom of player
    	ble  $t9, $t7, collision_check_right
   	j exist_touch_return
   	
collision_check_right:
	add  $t8, $t1, 3      # right side of the player
	beq  $t6, $t8, collision_check_right_y # if if right of player touch left side of object 
    	j skip_check_collision
   	
collision_check_right_y:
	addi $t9, $t2, 5       # bottom line of player.y +  5
   	add  $t8, $t7, $a1      # bottom line of object.y + object.height
   	# if top of player >= bottom line of object
   	ble  $t8, $t2, skip_check_collision
   	# if top of object >= bottom of player
    	ble  $t9, $t7, skip_check_collision
    	j exist_touch_return		

skip_check_collision:
	addi $t0, $t0, 1
	j check_collision_loop
	
exist_touch_return:
	li   $v0, 1
 	move $v1, $t5
   	jr $ra	

check_collision_end:	
	jr $ra
	
draw_score_point:  
	#store $ra
	addi $sp, $sp, -4
    	sw   $ra, 0($sp)
	jal address_of_pixel 
	move $t0, $v0 #get the address of pixel at the top left of the coin
   	
	li $t1, 0x00ffff #t1 stores the greenblue coulor code
	
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 512($t0)
	sw $t1, 516($t0)
	
	lw   $ra, 0($sp)
    	addi $sp, $sp, 4
    	jr $ra

erase_score_point:  
	#store $ra
	addi $sp, $sp, -4
    	sw   $ra, 0($sp)
	jal address_of_pixel 
	move $t0, $v0 #get the address of pixel at the top left of the coin
   	
	li $t1, 0x000000 #t1 stores the greenblue coulor code
	
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 512($t0)
	sw $t1, 516($t0)
	
	lw   $ra, 0($sp)
    	addi $sp, $sp, 4
    	jr $ra
# current score passed by $a0
draw_score_bar:
    # store $ra
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    # get current score
    addi $sp, $sp, -4
    sw $a0, 0($sp)  
	
    li $t2, 0             # index = 0

draw_score_bar_loop:
    beq $t2, 5, draw_score_bar_end   # max 5 score points

    # Compute x = 3 + index * 4            
    li $t4, 4             
    mul $t5, $t2, $t4     
    addi $a0, $t5, 3    #x
    li  $a1, 2           # y = 2
    
    lw $t1, 0($sp)		
    #use index to get whether score exist 
    blt $t2, $t1, draw_needed_score_point
    j draw_black_score_point

draw_needed_score_point:
    jal draw_score_point
    j draw_score_point_next

draw_black_score_point:
    jal erase_score_point

draw_score_point_next:
    addi $t2, $t2, 1
    j draw_score_bar_loop

draw_score_bar_end:
    # free stack for $a0 $ra
    addi $sp, $sp, 4
    # restore $ra
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra  	   	    	    	    	
    	    	    	    	    	
game_over:
	la $t0, player_coord
 	lw $a0, 0($t0)
	lw $a1, 4($t0)
	jal erase_player
	
	li $a0, 30      # start x
	li $a1, 3      # start y
	
	jal draw_letter_L
	
	addi $a0, $a0, 6
	jal draw_letter_O
	
	addi $a0, $a0, 6
	jal draw_letter_S
	
	addi $a0, $a0, 6
	jal draw_letter_T
	
	j program_end
	
you_won: 
	li $a0, 30     # start x
	li $a1, 3      # start y

	#jal draw_letter_U
	jal draw_letter_W
	
	addi $a0, $a0, 6
	jal draw_letter_I
	
	addi $a0, $a0, 6
	jal draw_letter_N
	
	j program_end
	
draw_letter_W:
	addi $sp, $sp, -4
    	sw $ra, 0($sp)
    	
	jal address_of_pixel 
	move $t0, $v0  #get the address of pixel at the top left
	
	li $t1, 0x00FFFFFF # white
	sw $t1, 0($t0)
	sw $t1, 16($t0)
	sw $t1, 512($t0)
	sw $t1, 520($t0)	
	sw $t1, 528($t0)
	sw $t1, 1024($t0)
	sw $t1, 1032($t0)
	sw $t1, 1040($t0)
	sw $t1, 1536($t0)
	sw $t1, 1544($t0)
	sw $t1, 1552($t0)
	sw $t1, 2052($t0)
	sw $t1, 2056($t0)
	sw $t1, 2060($t0)
	
	lw $ra, 0($sp)
    	addi $sp, $sp, 4
    	jr $ra
    	
draw_letter_I:
	addi $sp, $sp, -4
    	sw $ra, 0($sp)
    	
	jal address_of_pixel 
	move $t0, $v0  #get the address of pixel at the top left
	
	li $t1, 0x00FFFFFF # white
	sw $t1, 8($t0)
	sw $t1, 520($t0)
	sw $t1, 1032($t0)
	sw $t1, 1544($t0)
	sw $t1, 2056($t0)	
	
	
	lw $ra, 0($sp)
    	addi $sp, $sp, 4
    	jr $ra
    	
draw_letter_N:
	addi $sp, $sp, -4
    	sw $ra, 0($sp)
    	
	jal address_of_pixel 
	move $t0, $v0  #get the address of pixel at the top left
	
	li $t1, 0x00FFFFFF # white
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 16($t0)
	sw $t1, 512($t0)
	sw $t1, 520($t0)
	sw $t1, 528($t0)
	sw $t1, 1024($t0)
	sw $t1, 1032($t0)
	sw $t1, 1040($t0)
	sw $t1, 1536($t0)
	sw $t1, 1548($t0)
	sw $t1, 1552($t0)
	sw $t1, 2048($t0)
	sw $t1, 2060($t0)
	sw $t1, 2064($t0)
	
	lw $ra, 0($sp)
    	addi $sp, $sp, 4
    	jr $ra
    	
draw_letter_L:
	addi $sp, $sp, -4
    	sw $ra, 0($sp)
    	
	jal address_of_pixel 
	move $t0, $v0  #get the address of pixel at the top left
	
	li $t1, 0x00FFFFFF # white
	sw $t1, 0($t0)
	sw $t1, 512($t0)
	sw $t1, 1024($t0)
	sw $t1, 1536($t0)
	sw $t1, 2048($t0)
	sw $t1, 2052($t0)
	sw $t1, 2056($t0)
	sw $t1, 2060($t0)
	
	lw $ra, 0($sp)
    	addi $sp, $sp, 4
    	jr $ra
    	
draw_letter_O:
	addi $sp, $sp, -4
    	sw $ra, 0($sp)
    	
	jal address_of_pixel 
	move $t0, $v0  #get the address of pixel at the top left
	
	li $t1, 0x00FFFFFF # white
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 512($t0)
	sw $t1, 528($t0)
	sw $t1, 1024($t0)
	sw $t1, 1040($t0)
	sw $t1, 1536($t0)
	sw $t1, 1552($t0)
	sw $t1, 2048($t0)
	sw $t1, 2052($t0)
	sw $t1, 2056($t0)
	sw $t1, 2060($t0)
	sw $t1, 2064($t0)
	
	lw $ra, 0($sp)
    	addi $sp, $sp, 4
    	jr $ra
    	
draw_letter_S:
	addi $sp, $sp, -4
    	sw $ra, 0($sp)
    	
	jal address_of_pixel 
	move $t0, $v0  #get the address of pixel at the top left
	
	li $t1, 0x00FFFFFF # white
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 512($t0)
	sw $t1, 1024($t0)
	sw $t1, 1028($t0)
	sw $t1, 1032($t0)
	sw $t1, 1036($t0)
	sw $t1, 1040($t0)
	sw $t1, 1552($t0)
	sw $t1, 2048($t0)
	sw $t1, 2052($t0)
	sw $t1, 2056($t0)
	sw $t1, 2060($t0)
	sw $t1, 2064($t0)
	
	lw $ra, 0($sp)
    	addi $sp, $sp, 4
    	jr $ra
    	
draw_letter_T:
	addi $sp, $sp, -4
    	sw $ra, 0($sp)
    	
	jal address_of_pixel 
	move $t0, $v0  #get the address of pixel at the top left
	
	li $t1, 0x00FFFFFF # white
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 520($t0)
	sw $t1, 1032($t0)
	sw $t1, 1544($t0)
	sw $t1, 2056($t0)	
	
	
	lw $ra, 0($sp)
    	addi $sp, $sp, 4
    	jr $ra
    	