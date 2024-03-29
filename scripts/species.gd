class_name Species

const STALE_GENS_BEFORE_DEATH = 20
const FITNESS_NUM_TO_COMPARE = 5
const REQUIRED_SPECIES_IMPROVEMENT = 50
const CROSSOVER_RATE = 0.9
const DISABLED_LINK_SELECTION_RATE = 0.75
const TOP_GENOMES_RATE = 1.0
const INSPECIES_SELECTION_BIAS = 10.0

const Genome = preload("res://scripts/genome.gd")
const InputNode = preload("res://scripts/genome.gd").InputNode
const HiddenNode = preload("res://scripts/genome.gd").HiddenNode
const OutputNode = preload("res://scripts/genome.gd").OutputNode
const Link = preload("res://scripts/genome.gd").Link

var random = RandomNumberGenerator.new()

var prototype
var members
var parent_genomes
var avg_fitness
var total_adjusted_fitness
var population
var tint: Color
var creation_gen: int
var population_fraction
var species_id: int


func _init(_population, _prototype, _members=[], _parent_genomes=[], _avg_fitness=[],
      _total_adjusted_fitness=0):
  random.randomize()
  population = _population
  prototype = _prototype
  members = _members
  parent_genomes = _parent_genomes
  avg_fitness = _avg_fitness
  total_adjusted_fitness = _total_adjusted_fitness
  if population.species.size() > 1:
    tint = Color(random.randf(), random.randf(), random.randf())
  else:
    tint = Color(1.0, 1.0, 1.0) # normal form the first species
  # creation_gen = population.generation
  species_id = prototype.genome_id 


func share_fitness():
  for member_genome in members:
    member_genome.adjusted_fitness = float(member_genome.fitness / members.size())
    # print("member_genome.fitness: %s" % member_genome.fitness)
    # print("members.size: %s" % members.size())
    # print("adj fitness: %s" % member_genome.adjusted_fitness)
    # print("fitness / size: %s" % float(member_genome.fitness / members.size()))


func select_in_species(parents_number):
  # Calculate the avg_fitness and append it to the array
  # calculate_avg_fitness()
  # If no improvement in x generations then members = []
  empty_stale_spieces()

  # Calculate the number of parents for each species
  members.sort_custom(GenomeSorter, "sort_ascenting")
  # parent_genomes = []
  if members.size() == 0:
    parents_number = 0
  # Add the last (best performing) genomes of the species or random
  if parents_number > 0:
    for i in range(1, parents_number + 1):
      if members.size() >= i:
        # Append normal member
        parent_genomes.append(members[-i])
      else:
        # Append random member
        parent_genomes.append(members[random.randi_range(0, members.size() - 1)])

func calculate_avg_fitness():
  if members.size() == 0:
    avg_fitness = []
    total_adjusted_fitness = 0.0
    return

  var top_members = []
  members.sort_custom(GenomeSorter, "sort_ascenting")
  var top_num = max(1, int(round(members.size() * TOP_GENOMES_RATE)))
  for i in range(1, top_num + 1):
    top_members.append(members[-i])

  var total_fitness = 0.0
  for member_genome in top_members:
    total_fitness += member_genome.fitness
    total_adjusted_fitness += member_genome.adjusted_fitness
  if avg_fitness.size() < STALE_GENS_BEFORE_DEATH:
    avg_fitness.append(total_fitness / float(top_members.size()))
  else:
    avg_fitness.remove(0)
    avg_fitness.push_back(total_fitness / float(top_members.size())) # same as append

func empty_stale_spieces():
  if avg_fitness.size() >= STALE_GENS_BEFORE_DEATH:
    var avg_last_avg_fitness 
    var avg_first_avg_fitness 
    var total_last_avg_fitness = 0
    var total_first_avg_fitness = 0
    for i in range(0, FITNESS_NUM_TO_COMPARE):
      total_last_avg_fitness += avg_fitness[-(i+1)]
      total_first_avg_fitness += avg_fitness[i]
    avg_last_avg_fitness = total_last_avg_fitness / FITNESS_NUM_TO_COMPARE
    avg_first_avg_fitness = total_first_avg_fitness / FITNESS_NUM_TO_COMPARE
    # print("Last avg_fitness: %s, First: %s" % [avg_last_avg_fitness, avg_first_avg_fitness])
    if avg_last_avg_fitness - avg_first_avg_fitness < REQUIRED_SPECIES_IMPROVEMENT:
      pass
      # members = [] # if there is no improvement after some generations kill the species
    #   for member in members:
    #     member.added_mutation_rate += 0.1
    # else:
    #   for member in members:
    #     member.added_mutation_rate = 0.0


func crossover(noff_species):
  var crossovered_genomes = []
  # var one_extra_genome := false
  if parent_genomes.size() == 0:
    return []
  elif parent_genomes.size() % 2 != 0:
    parent_genomes.append(parent_genomes[0]) # add a genome to become even
    # one_extra_genome = true
  # Calculate total biased fitness of parent genomes
  var bias = INSPECIES_SELECTION_BIAS
  var total_biased_fitness := 0
  for parent_genome in parent_genomes:
    total_biased_fitness += parent_genome.fitness + bias
  # Crossover couples of parent_genomes in crossovered_genomes
  for i in range(0, parent_genomes.size(), 2):
    var couple_genomes = []
    var noff := 0
    var c_indices = []

    if i == 0:
      c_indices = [i, i]
    else:
      c_indices = [i-2, i-1]
    couple_genomes = [parent_genomes[c_indices[0]], parent_genomes[c_indices[1]]]
    # Couple's portion of the whole species' offspring
    var couple_fraction = (parent_genomes[c_indices[0]].fitness + parent_genomes[c_indices[1]].fitness + 2*bias) / total_biased_fitness
    # Number of offspring for the couple
    noff = int(couple_fraction * noff_species)

    var couple_crossovered_genomes = [] 
    if random.randf() < CROSSOVER_RATE:
      # couple_crossovered_genomes = couple_crossover(couple_genomes,
      #     number_of_offspring_each_couple)
      couple_crossovered_genomes = couple_crossover(couple_genomes, noff)
    else:
      # for c in number_of_offspring_each_couple:
      for c in noff:
        var genome_to_append = couple_genomes[c % 2]
        # genome_to_append.fitness = 0.0
        couple_crossovered_genomes.append(genome_to_append)
    crossovered_genomes.append_array(couple_crossovered_genomes)
  return crossovered_genomes

func couple_crossover(couple_genomes: Array, offspring_number: int) -> Array:
  var crossovered_genomes := []
  var fittest_parent
  var weakest_parent
  if couple_genomes[0].fitness > couple_genomes[1].fitness:
    fittest_parent = couple_genomes[0]
    weakest_parent = couple_genomes[1]
  else:
    fittest_parent = couple_genomes[1]
    weakest_parent = couple_genomes[0]

  for _i in offspring_number:
    var crossed_genome = Genome.new(population)

    crossed_genome.fitness = int(round((fittest_parent.fitness + weakest_parent.fitness) / 2))
    crossed_genome.species_id = fittest_parent.species_id
    crossed_genome.genome_id = population.generate_UIN()
    crossed_genome.weight_mutation_rate = fittest_parent.weight_mutation_rate
    crossed_genome.add_link_rate = fittest_parent.add_link_rate
    crossed_genome.add_node_rate = fittest_parent.add_node_rate
    crossed_genome.tint = fittest_parent.tint

    # inherit nodes from the fittest parent
    # Complicated thing needed to make independent copies of each input_node etc.
    var crossed_input_nodes := []
    for input_node in fittest_parent.input_nodes:
      var ogin = input_node.outgoing_link_inno_nums.duplicate()
      var new_i_node = InputNode.new(input_node.inno_num, input_node.name, ogin)
      crossed_input_nodes.append(new_i_node)
    crossed_genome.input_nodes = crossed_input_nodes

    var crossed_hidden_nodes := []
    for hidden_node in fittest_parent.hidden_nodes:
      var icin = hidden_node.incoming_link_inno_nums.duplicate()
      var ogin = hidden_node.outgoing_link_inno_nums.duplicate()
      var new_h_node = HiddenNode.new(hidden_node.inno_num, hidden_node.name, icin, ogin)
      crossed_hidden_nodes.append(new_h_node)
    crossed_genome.hidden_nodes = crossed_hidden_nodes

    var crossed_output_nodes := []
    for output_node in fittest_parent.output_nodes:
      var icin = output_node.incoming_link_inno_nums.duplicate()
      var new_o_node = OutputNode.new(output_node.inno_num, output_node.name, icin)
      crossed_output_nodes.append(new_o_node)
    crossed_genome.output_nodes = crossed_output_nodes

    var weakest_parent_inno_nums = []
    for link in weakest_parent.links:
      weakest_parent_inno_nums.append(link.inno_num)
    for link in fittest_parent.links:
      # Link is passed by reference too, so we need to make a new one to copy it
      var fit_link = Link.new(link.inno_num, link.weight, link.source_inno_num,
          link.target_inno_num, link.is_enabled)
      if fit_link.inno_num in weakest_parent_inno_nums: # matching links, random selection
        var w_link
        for wl in weakest_parent.links:
          if wl.inno_num == fit_link.inno_num:
            w_link = wl
            break
        var weak_link = Link.new(w_link.inno_num, w_link.weight, w_link.source_inno_num,
            w_link.target_inno_num, w_link.is_enabled)
        # If one of the two matching links is disabled, disable the offspring one in a certain rate 
        if !link.is_enabled:
          if random.randf() < DISABLED_LINK_SELECTION_RATE:
            crossed_genome.links.append(fit_link)
          else:
            crossed_genome.links.append(weak_link)
        elif !weak_link.is_enabled:
          if random.randf() < 1 - DISABLED_LINK_SELECTION_RATE:
            crossed_genome.links.append(fit_link)
          else:
            crossed_genome.links.append(weak_link)
        # Or else random choice between the two parent links
        elif random.randf() > 0.5:
          crossed_genome.links.append(fit_link)
        else:
          crossed_genome.links.append(weak_link)
      else: # excess or disjoint links, from the fittest
        crossed_genome.links.append(fit_link)
    crossovered_genomes.append(crossed_genome)
  return crossovered_genomes


# Reset everything except the prototype
func reset_species():
  members = []
  parent_genomes = []
  total_adjusted_fitness = 0.0



class GenomeSorter:
  static func sort_ascenting(a, b):
    if a.fitness < b.fitness:
      return true
    return false
