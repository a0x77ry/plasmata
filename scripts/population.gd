class_name Population

const ORIGINAL_SPECIES_NUMBER := 1
# const SELECTION_RATE = 0.3
const SELECTION_RATE = 0.3
const C1 := 0.5
const C2 := 0.5
const C3 := 0.4
# const dt := 55.4 # distance, original 0.35. More than 1 is to disable it
const dt := 0.4 # distance, original 0.35
const INSPECIES_SELECTION_BIAS = 50.0 # was 10.0
const CROSSOVER_RATE = 0.9
const DISABLED_LINK_SELECTION_RATE = 0.05 #was 0.75

const Species = preload("res://scripts/species.gd")
const Genome = preload("res://scripts/genome.gd")

const InputNode = preload("res://scripts/genome.gd").InputNode
const HiddenNode = preload("res://scripts/genome.gd").HiddenNode
const OutputNode = preload("res://scripts/genome.gd").OutputNode
const Link = preload("res://scripts/genome.gd").Link

var genomes
var species

var selection_rate
var target_population

var random = RandomNumberGenerator.new()
var max_IN_used := 0
var generation
var all_species_adj_fitness = 0.0

var parent_genomes := []


func _init(_genomes=[], _species=[], input_names=[], output_names=[],
    _generation=0, _target_population=0, _selection_rate=SELECTION_RATE):
  genomes = _genomes
  species = _species
  selection_rate = _selection_rate
  target_population = _target_population
  generation = _generation
  parent_genomes = genomes
  random.randomize()
  for _i in range(0, target_population):
    var new_genome = Genome.new(self)
    new_genome.init_io_nodes(input_names, output_names)
    genomes.append(new_genome)

  for genome in genomes:
    genome.species_id = genomes[0].genome_id # the first genome will be the prototype of the species
  species.append(Species.new(self, genomes[0], genomes))


# Changes genomes to the next generation
func next_generation(agents: Array):
  initialize_genomes_with_fitness(agents) # Initializes genomes array with fitness values only
  dummy_speciate() # Only one species
  # select_in_all_species(target_population) # Fills the parent_genomes in all species, calcs avg_fitness
  select_parents(round(target_population * selection_rate))
  # genomes = crossover_all_species()
  genomes = crossover(target_population)
  mutate_all_genomes()
  increment_generation()

# *** from species - begin ***

func select_parents(parents_number):
  parent_genomes = []

  # Calculate the number of parents for each species
  genomes.sort_custom(GenomeSorter, "sort_ascenting")
  assert(genomes.size() > 0)

  assert(parents_number < genomes.size())
  var genomes_temp = genomes
  for i in parents_number:
    parent_genomes.append(genomes_temp.pop_back())
  # Add the last (best performing) genomes of the species or random
  # for i in range(1, parents_number + 1):
  #   if genomes.size() >= i:
  #     # Append normal member
  #     parent_genomes.append(genomes[-i])
  #   else:
  #     # Append random member
  #     print("Adding random")
  #     parent_genomes.append(genomes[random.randi_range(0, genomes.size() - 1)])


func crossover(noff_pop):
  var crossovered_genomes = []
  assert(parent_genomes.size() > 0)
  if parent_genomes.size() % 2 != 0:
    parent_genomes.push_front(parent_genomes[0]) # add a genome to become even
  # Calculate total biased fitness of parent genomes
  var bias = INSPECIES_SELECTION_BIAS
  var total_biased_fitness := 0
  var min_fitness = parent_genomes[-1].fitness
  for parent_genome in parent_genomes:
    parent_genome.fitness = max(0.0, parent_genome.fitness - min_fitness)
    total_biased_fitness += parent_genome.fitness + bias
  # Crossover couples of parent_genomes in crossovered_genomes
  var c_indices = []
  var couple_genomes = []
  for i in range(0, parent_genomes.size(), 2):
    var noff := 0

    if i == 0:
      c_indices = [i, i]
    else:
      c_indices = [i-2, i-1]
    couple_genomes = [parent_genomes[c_indices[0]], parent_genomes[c_indices[1]]]
    # Couple's portion of the whole species' offspring
    var couple_fraction = (parent_genomes[c_indices[0]].fitness + parent_genomes[c_indices[1]].fitness + 2*bias) / total_biased_fitness
    # Number of offspring for the couple
    noff = int(couple_fraction * noff_pop)

    var couple_crossovered_genomes = [] 
    if random.randf() < CROSSOVER_RATE:
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
    var crossed_genome = Genome.new(self)

    crossed_genome.fitness = int(round((fittest_parent.fitness + weakest_parent.fitness) / 2))
    crossed_genome.species_id = fittest_parent.species_id
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

func dummy_speciate():
  if species.size() == 0:
    add_new_species(genomes[0])
    print("new species")
  empty_species(species[0])
  for genome in genomes:
    add_member_to_species(species[0], genome)

func empty_species(sp):
    sp.members = []

# Initializes genomes array with fitness values only
func initialize_genomes_with_fitness(agents: Array):
  var _genomes = []
  for agent in agents:
    agent.get_fitness()
    _genomes.append(agent.genome)
  genomes = _genomes.duplicate()


func mutate_all_genomes():
  for genome in genomes:
    genome.mutate()


func crossover_all_species() -> Array:
  assert(species[0].parent_genomes.size() > 0)
  var crossovered_genomes := []
  crossovered_genomes.append_array(species[0].crossover(target_population))
  return crossovered_genomes

# func cross_species(pop):
#   var crossovered_genomes := []
#   var noff_remainder := 0.0
#   for sp in species:
#     var real_noff = sp.population_fraction * pop
#     var noff = int(floor(real_noff))
#     noff_remainder += real_noff - noff
#     crossovered_genomes.append_array(sp.crossover(noff))
#   if noff_remainder >= 1.0:
#     crossovered_genomes.append_array(cross_species(int(floor(noff_remainder))))
#   return crossovered_genomes


# Fills the parent_genomes in all species
func select_in_all_species(total_pop):
  assert(species.size() == 1)
  species[0].parent_genomes = []
  species[0].population_fraction = 1.0
  species[0].select_in_species(round(total_pop * selection_rate)) 
  assert(species[0].parent_genomes.size() > 0)


func add_new_species(genome):
  var sp = Species.new(self, genome, [genome])
  genome.tint = sp.tint
  # genome.gen_num = sp.creation_gen
  genome.species_id = sp.species_id
  species.append(sp)

func add_member_to_species(sp, genome):
  sp.members.append(genome)
  genome.species_id = sp.species_id
  genome.tint = sp.tint


func generate_UIN():
  max_IN_used += 1
  return max_IN_used


func add_UIN(inno_num):
  if inno_num > max_IN_used:
    max_IN_used = inno_num
  return inno_num


func increment_generation():
  generation += 1


class GenomeSorter:
  static func sort_ascenting(a, b):
    if a.fitness < b.fitness:
      return true
    return false
