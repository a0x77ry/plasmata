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
var population_number

var random = RandomNumberGenerator.new()
var max_IN_used := 0


func _init(_genomes=[], input_names=[], output_names=[],
    _population_number=0, _selection_rate=SELECTION_RATE, is_dummy:=false):
  if is_dummy:
    return
  genomes = _genomes.duplicate()
  selection_rate = _selection_rate
  population_number = _population_number
  random.randomize()
  for _i in range(0, population_number):
    var new_genome = Genome.new(self)
    new_genome.init_io_nodes(input_names.duplicate(), output_names.duplicate())
    genomes.append(new_genome)
  mutate_all_genomes()

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
