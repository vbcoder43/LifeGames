extends Node2D
# size in pixels
@export var GRID_SIZE = 64
@export var CELL_SIZE = 8

var grid = []
var grid_next = []
var start = false

func _ready():
	randomize()
	for x in range(GRID_SIZE):
		var row_temp = []
		for y in range(GRID_SIZE):
			#row_temp.append(randf_range(0.0, 1.0) > 0.5)
			row_temp.append(0)
		grid.append(row_temp)
		grid_next.append(row_temp.duplicate())
	#glider
	grid[5][5]=1
	grid[6][6]=1
	grid[7][4]=1
	grid[7][5]=1
	grid[7][6]=1
	#oscillator
	grid[2][1]=1
	grid[2][2]=1
	grid[2][3]=1
	grid[2][4]=1
	grid[2][5]=1

func _process(delta):
	DisplayServer.window_set_title(str(delta*1000.0)+" ms, "+str(1/delta)+" fps")
	if Input.is_action_pressed("ui_accept"):
		start = true
	if start:
		for x in range(GRID_SIZE):
			for y in range(GRID_SIZE):
				var neighbors = get_neighbor_count(x, y)
				#if neighbors!=0:
					#print([x,y]," ",neighbors)
				if grid[x][y]:
					grid_next[x][y] = ((neighbors == 2) or (neighbors == 3))
				else:
					grid_next[x][y] = (neighbors == 3)
		var temp = grid
		grid = grid_next
		# I have no clue why i need to swap the grids here to make it work
		# probably the state needs to be saved so next updates appear correct
		grid_next = temp
		#print("----------------")
		queue_redraw()

func _draw():
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			var col = Color.WHITE if grid[x][y] else Color.BLACK
			#draw_rect(Rect2(x*CELL_SIZE, y*CELL_SIZE, CELL_SIZE, CELL_SIZE), Color.RED, false, 1.0)
			draw_rect(Rect2(x*CELL_SIZE, y*CELL_SIZE, CELL_SIZE, CELL_SIZE), col)

func get_neighbor_count(x, y):
	var count = 0
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if (dx==0 and dy==0):
				continue
			# out of array protection/wrap around
			var nx = (x+dx+GRID_SIZE)%GRID_SIZE
			var ny = (y+dy+GRID_SIZE)%GRID_SIZE
			if grid[nx][ny]:
				count += 1
	return count
