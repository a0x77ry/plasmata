class_name Population

const SELECTION_RATE = 0.2
const INSPECIES_SELECTION_BIAS = 0.0 # was 10.0
const CROSSOVER_RATE = 1.0
const DISABLED_LINK_SELECTION_RATE = 0.05 #was 0.75

const Genome = preload("res://scripts/genome.gd")

const InputNode = preload("res://scripts/genome.gd").InputNode
const HiddenNode = preload("res://scripts/genome.gd").HiddenNode
const OutputNode = preload("res://scripts/genome.gd").OutputNode
const Link = preload("res://scripts/genome.gd").Link

var genomes

var selection_rate
var population_stream

var random = RandomNumberGenerator.new()
var max_IN_used := 0
var generation

# var parent_genomes := []


func _init(_genomes=[], input_names=[], output_names=[],
    _generation=0, _population_stream=0, _selection_rate=SELECTION_RATE):
  genomes = _genomes
  selection_rate = _selection_rate
  population_stream = _population_stream
  generation = _generation
  # parent_genomes = genomes
  random.randomize()
  for _i in range(0, population_stream):
    var new_genome = Genome.new(self)
    new_genome.init_io_nodes(input_names, output_names)
    genomes.append(new_genome)
  mutate_all_genomes()


# Changes genomes to the next generation
# func next_generation(agents: Array):
#   initialize_genomes_with_fitness(agents) # Initializes genomes array with fitness values only
#   select_parents(round(agents.size() * selection_rate))
#   genomes = crossover(population_stream)
#   mutate_all_genomes()
#   generation += 1

# *** from species - begin ***

# func select_parents(parents_number):
#   parent_genomes = []
#
#   # Calculate the number of parents for each species
#   genomes.sort_custom(GenomeSorter, "sort_ascenting")
#   assert(genomes.size() > 0)
#
#   var genomes_temp = genomes.duplicate()
#   for i in parents_number:
#     parent_genomes.append(genomes_temp.pop_back().duplicate())
#
#   genomes_temp = []


# func crossover(noff_pop):
#   var crossovered_genomes = []
#   assert(parent_genomes.size() > 0)
#   if parent_genomes.size() % 2 != 0:
#     parent_genomes.push_front(parent_genomes[0]) # add a genome to become even
#   # Calculate total biased fitness of parent genomes
#   var bias = INSPECIES_SELECTION_BIAS
#   var total_biased_fitness := 0
#   for parent_genome in parent_genomes:
#     total_biased_fitness += parent_genome.fitness + bias
#   # Crossover couples of parent_genomes in crossovered_genomes
#   var c_indices = []
#   var couple_genomes = []
#   for i in range(0, parent_genomes.size(), 2):
#     var noff := 0
#
#     if i == 0:
#       c_indices = [i, i]
#     else:
#       c_indices = [i-2, i-1]
#     couple_genomes = [parent_genomes[c_indices[0]], parent_genomes[c_indices[1]]]
#     # Couple's portion of the whole species' offspring
#     # var couple_fraction = (parent_genomes[c_indices[0]].fitness + parent_genomes[c_indices[1]].fitness + 2*bias) / total_biased_fitness
#     # Number of offspring for the couple
#     noff = round(((parent_genomes[c_indices[0]].fitness + parent_genomes[c_indices[1]].fitness + 2*bias) * noff_pop) / total_biased_fitness)
#
#     var couple_crossovered_genomes = [] 
#     if random.randf() < CROSSOVER_RATE:
#       couple_crossovered_genomes = couple_crossover(couple_genomes, noff)
#     else:
#       # for c in number_of_offspring_each_couple:
#       for c in noff:
#         var genome_to_append = couple_genomes[c % 2]
#         genome_to_append.fitness = 0.0
#         couple_crossovered_genomes.append(genome_to_append)
#     crossovered_genomes.append_array(couple_crossovered_genomes)
#   return crossovered_genomes

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
    var crossed_genome = Genome.new(self)

    crossed_genome.fitness = int(round((fittest_parent.fitness + weakest_parent.fitness) / 2))
    crossed_genome.genome_id = generate_UIN()
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

# *** from species - end ***

# Initializes genomes array with fitness values only
# func initialize_genomes_with_fitness(agents: Array):
#   var _genomes = []
#   for agent in agents:
#     agent.assign_fitness()
#     _genomes.append(agent.genome.duplicate())
#   genomes = _genomes.duplicate()


func mutate_all_genomes():
  for genome in genomes:
    genome.mutate()


func generate_UIN():
  max_IN_used += 1
  return max_IN_used


func add_UIN(inno_num):
  if inno_num > max_IN_used:
    max_IN_used = inno_num
  return inno_num


class GenomeSorter:
  static func sort_ascenting(a, b):
    if a.fitness < b.fitness:
      return true
    return false
