require 'rubygems'
require 'gosu'

# Global constants
WIDTH, HEIGHT = 740, 500 # Screen window size
PREDICTION_THRESHOLD = 0.55 # Prediction threshold above which dino should jump
MUTATE_GENES = true # Whether or not to mutate genes
OUTPUT_TIME = 600 # How long must we run program before outputting high score results by generation number for data analysis

module ZOrder
	BACKGROUND, MIDDLE, TOP, BORDER = *0..3
end

# Obstacles of small width
class Obstacle
	attr_accessor :x, :y, :type, :width

	def initialize(image, x, y)
		@image = image
		@x, @y = x, y
		@type = "0"
		@width = 35
	end

	def draw
		@image.draw(@x, @y-25, 0, 1.0, 1.0)
	end
end

# Obstacles of large width
class ObstacleWide
	attr_accessor :x, :y, :type, :width

	def initialize(image, x, y)
		@image = image
		@x, @y = x, y
		@type = "1"
		@width = 60
	end

	def draw
		@image.draw(@x, @y-25, 0, 1.0, 1.0)
	end
end

module Tiles
	Grass = 0
	Earth = 1
end

# Dinosaur population data type
class Population
	attr_accessor :death_count, :gen_number, :dinos, :scores
	
	def initialize(dinos, gen_number)
		@death_count = 0
		@gen_number = gen_number
		@dinos = dinos
		@scores = Array.new(10, 0) # Array of dinosaur scores
	end
end

# Dinorsaur data type
class Dinosaur
	attr_accessor :num_label, :x, :y, :chromosome, :is_alive, :death_count, :score, :collision

	def initialize(num, map, x, y)
		@num_label = num
		@chromosome = Array.new()
		for i in (0..3)
			@chromosome << rand(0..1.0)
		end
		@x, @y = x, y
		@vy = 0 # Vertical velocity
		@map = map
		
		# Dino images for different animations
		@standing = Gosu::Image.new("standing.png")
		@walk1 = Gosu::Image.new("step1.png")
		@walk2 = Gosu::Image.new("step2.png")
		@jump = Gosu::Image.new("jump.png")
		@cur_image = @standing  
		
		@is_alive = true # Is the dino alive?
		@score = 0
		@collision = false
	end
	
	def draw
		# Flip vertically when facing to the left.
		if @dir == :right
			offs_x = -25
			factor = 1.0
		end
		@cur_image.draw(@x + offs_x, @y - 49, 0, factor, 1.0)#-49, 0, factor, 1.0)
	end
	
	# Could the object be placed at x + offs_x/y + offs_y without being stuck?
	def would_fit(population, offs_x, offs_y)
		# Check at the center/top and center/bottom for map collisions 
		if not @map.solid?(@x + offs_x, @y + offs_y) and not @map.solid?(@x + offs_x, @y + offs_y - 45)
			no_obs = true
		else
			no_obs = false
		end
		
		if not @collision
			no_col = true
		else
			@is_alive = false # Dino dies on collision with obstacle
			no_col = false
		end
		
		if no_obs and no_col
			return true
		else
			return false
		end 
	end
	
	def update(population, move_x)
		# Select image depending on action
		if (move_x == 0)
		  @cur_image = @standing
		else
		  @cur_image = (Gosu.milliseconds / 175 % 2 == 0) ? @walk1 : @walk2
		end
		
		# Make dino jump
		if (@vy < 0)
		  @cur_image = @jump
		end
		
		# Directional walking, horizontal movement
		if move_x > 0
		  @dir = :right
		  move_x.times { if would_fit(population, 1, 0) then @x += 1 end }
		end
		
		# Acceleration/gravity
		# By adding 1 each frame, and (ideally) adding vy to y, the player's
		# jumping curve will be the parabole we want it to be.
		@vy += 1
		
		# Vertical movement
		if @vy > 0
		  @vy.times { if would_fit(population, 0, 1) then @y += 1 else @vy = 0 end }
		end
		
		if @vy < 0
		  (-@vy).times { if would_fit(population, 0, -1) then @y -= 1 else @vy = 0 end }
		end
  end
  
  # Try to jump over obstacle
  def try_to_jump
    if @map.solid?(@x, @y + 1)
      @vy = -20
    end
  end

end

# Map class holds and draws tiles and obstacles.
class Map
	attr_reader :width, :height, :obstacles
	
	def initialize(filename)
	# Load 60x60 tiles, 5px overlap in all four directions.
	@tileset = Gosu::Image.load_tiles("media/tileset.png", 60, 60, tileable: true)

	obstacle_img = Gosu::Image.new("cactus-1.png")
	obstacle_wide_img = Gosu::Image.new("cactus-2.png")
	@obstacles = []
	@obstacles_wide = []

	lines = File.readlines(filename).map { |line| line.chomp }
	@height = lines.size
	@width = lines[0].size
	
	# Create tiles for the dino game
	@tiles = Array.new(@width) do |x|
	  Array.new(@height) do |y|
		case lines[y][x, 1]
		when '#'
		  Tiles::Earth
		when '0'
		  @obstacles.push(Obstacle.new(obstacle_img, x * 50 + 25, y * 50 + 25))
		  nil
		when '1'	
		  @obstacles.push(ObstacleWide.new(obstacle_wide_img, x * 50 + 25, y * 50 + 25))
		  nil
		else
		  nil
		end
	  end
	end
	end
  
	def draw
		# Very primitive drawing function:
		# Draws all the tiles, some off-screen, some on-screen.
		@height.times do |y|
		  @width.times do |x|
			tile = @tiles[x][y]
			if tile
			  # Draw the tile with an offset (tile images have some overlap)
			  # Scrolling is implemented here just as in the game objects.
			  @tileset[tile].draw(x * 50 - 5, y * 50 - 5, 0)
			else 
				Gosu.draw_rect(x * 50 - 5, y * 50 - 5, 60, 60, Gosu::Color.argb(0xff_808080), 0, mode = :default)
			end
		  end
		end
		@obstacles.each { |c| c.draw }
		@obstacles_wide.each { |c| c.draw }
	end
	
	# Check whether the dino will collide with an obstacle
	def collision?(population, dino, x, y)
		obs_height = 24
		col = false
		col_set = false
		distance_to_obstacles = Array.new
		i = 0
		@obstacles.each do |c|
			obs_width = c.width
			distance_to_obstacles << c.x-x-obs_width
			if x.between?(c.x-15, c.x+2*c.width)
				if y.between?(c.y-obs_height, c.y+obs_height)
					if not col_set
						return true, distance_to_obstacles, obs_width
					end
				else
					col = false
				end
			else 
				if c.type == "0"
					if x > c.x + c.width + 50
						@obstacles.delete_at(i)
					end
				elsif c.type == "1"
					if x > c.x + c.width + 100
						@obstacles.delete_at(i)
					end 
				end
				col = false
			end
			i += 1
		end	
		obs_width = @obstacles[0].width
		return col, distance_to_obstacles, obs_width
	end
	
	# Solid at a given pixel position?
	def solid?(x, y)
		y < 0 || @tiles[x / 50][y / 50]
	end
end

# Update dinosaur scores
def update_score(population)
	i = 0
	pop_size = population.dinos.length
	while i < pop_size
		if population.dinos[i].is_alive == true
			population.dinos[i].score += population.dinos[i].x.to_f/1000
			population.scores[i] = population.dinos[i].score
		end
		i += 1
	end
end

# Get the fitness of dinosaur population
def fitness(scores)
	num_dinos = scores.length
	scores = scores.sort_by { |dino, score| score }
	
	return scores[num_dinos - 1][0].to_i, scores[num_dinos - 2][0].to_i, scores[0][0].to_i, scores[1][0].to_i

end

# Select the two fittest individuals and the two least fit individuals
def selection(dinos)
	scores = Hash.new
	num_dinos = dinos.length
	i = 0
	
	# Check the scores
	while i < num_dinos
		scores[i.to_s] = dinos[i].score
		i += 1
	end
	
	fittest, second_fittest, least_fittest, second_least_fittest = fitness(scores)
	return [fittest, second_fittest], [least_fittest, second_least_fittest] 
end

# Perform crossover process, mate the two fittest individuals
def crossover(dinos, parents, least_fit_of_pop)
	fittest_parent_chromosome = dinos[parents[0]].chromosome
	second_fittest_parent_chromosome = dinos[parents[1]].chromosome
	slice_point = rand(0...4.0).floor # Also known as the cross over point for genetic algorithm
	first_child_chromosome = Array.new
	second_child_chromosome = Array.new
	
	# Now we perform crossover operation on the children
	i = 0
	while i < 4
		if i < slice_point
			first_child_chromosome << fittest_parent_chromosome[i]
			second_child_chromosome << second_fittest_parent_chromosome[i]
		else
			first_child_chromosome << second_fittest_parent_chromosome[i]
			second_child_chromosome << fittest_parent_chromosome[i]
		end
		i += 1
	end
	
	# Replace the two least fit individuals with the two new offspring
	dinos[least_fit_of_pop[0]].chromosome = first_child_chromosome
	dinos[least_fit_of_pop[1]].chromosome = second_child_chromosome
	
	return dinos, least_fit_of_pop[0], least_fit_of_pop[1]
end

# Mutate offspring
def mutate(dinos, first_child, second_child)
	do_we_mutate_child_1 = rand(0..1.0) # Do we mutate the first child?
	do_we_mutate_child_2 = rand(0..1.0) # Do we mutate the second child?
	
	if do_we_mutate_child_1 > 0.5
		mutate_gene_child_1 = rand(0...4.0) # Select gene to mutate
		dinos[first_child].chromosome[mutate_gene_child_1.floor] = rand(0..1.0)
	end
	
	if do_we_mutate_child_2 > 0.5
		mutate_gene_child_2 = rand(0...4.0) # Select gene to mutate
		dinos[second_child].chromosome[mutate_gene_child_2.floor] = rand(0..1.0)
	end
	
	dinos
end

# The training function performs selection and mutation operators on the population to create new population
def train(dinos)
	parents, least_fit_of_pop = selection(dinos)
	dinos, first_child, second_child = crossover(dinos, parents, least_fit_of_pop)
	
	# Only mutate genes if MUTATE_GENES is set to true
	if MUTATE_GENES
		dinos = mutate(dinos, first_child, second_child)
	end	
	
	dinos
end

# Predict/decide whether or not dinosaur should jump
def predict(input_0, input_1, input_2, dino)
	prediction = (input_0*dino.chromosome[0] + input_1*dino.chromosome[1] + (input_2/2)*dino.chromosome[2] + dino.chromosome[3])/(input_0 + input_1 + (input_2/2) + 1)#((Math.sqrt(input_0*input_0+input_1*input_1+(input_2/2)*(input_2/2)+1))*Math.sqrt((dino.chromosome[0]*dino.chromosome[0]+dino.chromosome[1]*dino.chromosome[1]+dino.chromosome[2]*dino.chromosome[2]+dino.chromosome[3]*dino.chromosome[3])))

	if prediction > PREDICTION_THRESHOLD
		dino.try_to_jump
	end
end

# Where bulk of the program is run. We make dinos move and jump over obstacles
# by making a prediction on whether dino should or should not jump
# and print information relating to dinos
def run_update(map, pop_size, population, camera_x, camera_y, move_x)
	for i in (0..pop_size-1)		
		if population.dinos[i].is_alive
			collision, get_distance_next_object_array, obs_width = map.collision?(population, population.dinos[i], population.dinos[i].x, population.dinos[i].y)
			population.dinos[i].collision = collision
			population.dinos[i].update(population, move_x)
			
			# Scrolling follows player
			camera_x = [[population.dinos[i].x - 30, 0].max, map.width * 50 - WIDTH].min
			camera_y = [[population.dinos[i].y - HEIGHT / 2, 0].max, map.height * 50 - HEIGHT].min
			get_distance_next_object = get_distance_next_object_array.min
			if population.dinos[i].y == 399
				predict(get_distance_next_object, move_x, obs_width, population.dinos[i])
			end
			info_x = population.dinos[i].x + WIDTH / 1.8
		end
	end
	
	return map, population, camera_x, camera_y, info_x, get_distance_next_object
end

# Output high scores to a file
def output_high_scores_by_gen_number(high_scores, generations)
	file = File.open("output_mutate_genes_" + MUTATE_GENES.to_s + "_prediction_threshold_" + PREDICTION_THRESHOLD.to_s + ".txt", "w")
	
	for i in (0..high_scores.length - 1)
		file.puts(high_scores[i].to_s + " " + generations[i].to_s)
	end
	
	file.close
end

# Main Gosu window
class DinoGame < Gosu::Window

	def init_pop(dinos, gen_number)
		@map = Map.new("map.txt")
		@camera_x = @camera_y = 0
		@pop_size = 10
		
		if gen_number == 0
			dinos = Array.new()
			for i in (0..@pop_size-1)
				dino = Dinosaur.new(i, @map, 10, 300)
				dinos << dino
			end
			@population = Population.new(dinos, gen_number)
		else
			prev_dinos = train(dinos)
			dinos = Array.new()
			for i in (0..@pop_size-1)
				dino = Dinosaur.new(i, @map, 10, 300)
				dinos << dino
			end
			
			for i in (0..@pop_size-1)
				dinos[i].chromosome = prev_dinos[i].chromosome
			end
			
			@population = Population.new(dinos, gen_number)
		end
		
		for i in (0..@pop_size-1)
			puts "Dino " + i.to_s + ": " + @population.dinos[i].chromosome.to_s
		end
		
		puts " "
	end

	# set up variables and attributes
	def initialize		
		super(WIDTH, HEIGHT, false)
		@camera_x = @camera_y = 0
		@info_font = Gosu::Font.new(16)
		@info_y = 0
		@num_gens = 10
		@gen_number = 0
		@move_x = 0
		@vx = 5
		@num_update = 0
		init_pop([], 0)
		@high_scores = []
		@generations = []
		@start_time = Time.now
		@results_not_outputted = true
	end
	
	# Print dino scores
	def print_scores
		i = 0
		while i < @population.dinos.length
			@info_font.draw("Score: #{@population.dinos[i].score}", @info_x, @info_y + 120 + i*10, ZOrder::TOP, 1.0, 1.0, Gosu::Color::WHITE)
			i += 1
		end
	end
	
	# Print dino information in window
	def print_info(population, dino, dino_num)
		@info_font.draw("Dino pos_x: #{dino.x}", @info_x, @info_y, ZOrder::TOP, 1.0, 1.0, Gosu::Color::WHITE)
		@info_font.draw("Dino pos_y: #{dino.y}", @info_x, @info_y + 20, ZOrder::TOP, 1.0, 1.0, Gosu::Color::WHITE)
		@info_font.draw("Distance to next obstacle: #{@get_distance_next_object}", @info_x, @info_y + 40, ZOrder::TOP, 1.0, 1.0, Gosu::Color::WHITE)
		@info_font.draw("Generation: #{population.gen_number}", @info_x, @info_y + 60, ZOrder::TOP, 1.0, 1.0, Gosu::Color::WHITE)
		@info_font.draw("Population count: #{@pop_size-population.death_count}", @info_x, @info_y + 80, ZOrder::TOP, 1.0, 1.0, Gosu::Color::WHITE)
		@info_font.draw("Game speed: #{@move_x}", @info_x, @info_y + 100, ZOrder::TOP, 1.0, 1.0, Gosu::Color::WHITE)
		# print_scores
	end

	def draw
		Gosu.translate(-@camera_x, -@camera_y) do
			@map.draw
			for i in (0..@pop_size-1)
				if @population.dinos[i].is_alive
					@population.dinos[i].draw # Draw the dinos during the main Gosu cycle
					print_info(@population, @population.dinos[i], i) # Print dino information on top right
				end
			end
		end
		@population.death_count = 0
		for i in (0..@pop_size-1)
			if not @population.dinos[i].is_alive
				@population.death_count += 1 # If a dino is not alive, then increase the death count for the population
			end
		end
		if @population.death_count == @pop_size
			@move_x = 0
			@vx = 5
			@num_update = 0
			@generations << @gen_number
			@high_scores << @population.scores.max
			@end_time = Time.now

			time_difference = @end_time - @start_time
			
			# Output high scores for each population/generation after waiting a reasonable time to collect results. This 
			# OUTPUT_TIME is somewhat of a sampling time
			if time_difference > OUTPUT_TIME and @results_not_outputted
				output_high_scores_by_gen_number(@high_scores, @generations)
				@results_not_outputted = false
			end
			
			@gen_number += 1
			init_pop(@population.dinos, @gen_number)
		end
	end

	# Update Gosu window
	def update
		update_score(@population)
		
		if (@num_update % 500 == 0 and @num_update > 0)
			@vx += 1
		end
		
		@move_x = @vx 
		
		# The run_update function updates the state of the dino population at each iteration of the Gosu cycle
		@map, @population, @camera_x, @camera_y, @info_x, @get_distance_next_object = run_update(@map, @pop_size, @population, @camera_x, @camera_y, @move_x)
		@num_update += 1
	end
end

# Lets get started!
DinoGame.new.show
