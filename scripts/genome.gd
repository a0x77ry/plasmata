class_name Genome

const MUTATION_RATE = 0.8
const WEIGHT_SHIFT_RATE = 0.9
const EXPECTED_MUTATED_GENE_RATE = 0.1
const EXPECTED_DISABLING_RATE = EXPECTED_MUTATED_GENE_RATE / 2
const MUTATION_STANDARD_DEVIATION = 2.0
const ORIGINAL_WEIGHT_VALUE_LIMIT = 2.0
const ADD_LINK_RATE = 0.3
const ADD_NODE_RATE = 0.2 # original : 0.25

var input_nodes
var hidden_nodes
var output_nodes
var links
var fitness
var population

var adjusted_fitness
var random = RandomNumberGenerator.new()


func _init(_population, _input_nodes=[], _hidden_nodes=[], _output_nodes=[],
    _links=[], _fitness=0):
  population = _population
  input_nodes = _input_nodes
  hidden_nodes = _hidden_nodes
  output_nodes = _output_nodes
  links = _links
  fitness = _fitness


func init_io_nodes(input_names: Array, output_names: Array):
  var i := 0
  for i_name in input_names:
    input_nodes.append(InputNode.new(population.add_UIN(i), i_name))
    i += 1
  for o_name in output_names:
    output_nodes.append(OutputNode.new(population.add_UIN(i), o_name))
    i += 1


# Mutate this specific genome
func mutate():
  random.randomize()
  if random.randf() < MUTATION_RATE:
    for link in links:
      # Shift weights
      if random.randf() < WEIGHT_SHIFT_RATE:
        if random.randf() < EXPECTED_MUTATED_GENE_RATE:
          link.weight = random.randfn(link.weight, MUTATION_STANDARD_DEVIATION)
      # Change weights randomly
      else:
        if random.randf() < EXPECTED_MUTATED_GENE_RATE:
          link.weight = random.randf_range(-ORIGINAL_WEIGHT_VALUE_LIMIT, ORIGINAL_WEIGHT_VALUE_LIMIT)
      # Disable link
      if random.randf() < EXPECTED_DISABLING_RATE:
        link.is_enabled = !link.is_enabled
    # Add a link
    if random.randf() < ADD_LINK_RATE:
      var source_nodes = input_nodes + hidden_nodes
      var source_node = source_nodes[random.randi_range(0, source_nodes.size() - 1)]
      var target_node = choose_target_node(source_node)
      if target_node != null:
        var new_inno_num = population.generate_UIN()
        var new_link = Link.new(new_inno_num, #source_node, target_node,
            random.randf_range(-ORIGINAL_WEIGHT_VALUE_LIMIT, ORIGINAL_WEIGHT_VALUE_LIMIT),
            source_node.inno_num, target_node.inno_num, true)
        links.append(new_link)
        source_node.add_outgoing_link(new_link)
        target_node.add_incoming_link(new_link)

    # Add a new node and break the link
    if links.size() == 0:
      return # cannot break a link if there isn't one
    # TRY
    if random.randf() < ADD_NODE_RATE:
      # find a random link to break
      var link_to_break
      while link_to_break == null:
        for genome_link in links:
          if random.randf() < float(1.0 / links.size()):
            link_to_break = genome_link
            break
      link_to_break.is_enabled = false # original link disabled
      # find the source and target nodes of the original link that is about to break
      var original_source_node
      for genome_source_node in input_nodes + hidden_nodes:
        if link_to_break.source_inno_num == genome_source_node.inno_num:
          original_source_node = genome_source_node
      var original_target_node
      for genome_target_node in output_nodes + hidden_nodes:
        if link_to_break.target_inno_num == genome_target_node.inno_num:
          original_target_node = genome_target_node
      # construct the new hidden node and append it to hidden_nodes
      var new_hidden_node = HiddenNode.new(population.generate_UIN(), [], [])
      hidden_nodes.append(new_hidden_node)
      # create the new links for the new hidden node
      var link_a = Link.new(population.generate_UIN(),
          # original_source_node,
          # new_hidden_node,
          1.0, original_source_node.inno_num, new_hidden_node.inno_num, true)
      var link_b = Link.new(population.generate_UIN(),
          # new_hidden_node,
          # original_target_node,
          link_to_break.weight, new_hidden_node.inno_num, original_target_node.inno_num, true)
      links.append(link_a)
      links.append(link_b)
      new_hidden_node.add_incoming_link(link_a)
      new_hidden_node.add_outgoing_link(link_b)
      original_source_node.add_outgoing_link(link_a)
      original_target_node.add_incoming_link(link_b)

func link_already_exists(source_node, target_node):
  # if target_node.incoming_links != null: # Because it can be an input node in the recursion
  if "incoming_link_inno_nums" in target_node:
    for inlink_inno_num in target_node.incoming_link_inno_nums:
      var inlink
      for l in links:
        if l.inno_num == inlink_inno_num:
          inlink = l
      if inlink.source_inno_num == source_node.inno_num:
        return true
  return false

func is_circular_loop(source_node, target_node):
  if source_node.inno_num == target_node.inno_num:
    return true
  for link in links:
    if link.source_inno_num == target_node.inno_num && link.target_inno_num == source_node.inno_num:
      return true
    
  if "outgoing_link_inno_nums" in target_node: # Because it can be an output node as a candidate target
    for outlink_inno_num in target_node.outgoing_link_inno_nums:
      var outlink
      for l in links:
        if l.inno_num == outlink_inno_num:
          outlink = l

      # In order to recurse we first have to find the target node of the target_node when it is not the source node
      var candidate_target_nodes = hidden_nodes
      var target_of_the_target_node
      for node in candidate_target_nodes:
        if node.inno_num == outlink.target_inno_num:
          target_of_the_target_node = node # this can be null because the target of the link is an output node
      if target_of_the_target_node != null && is_circular_loop(source_node, target_of_the_target_node):
        return true
  return false

func choose_target_node(source_node): # Needed for mutate()
  var candidate_nodes = hidden_nodes + output_nodes
  var unlinked_nodes = []
  for target_node in candidate_nodes:
    var is_node_linked := false
    if target_node.inno_num == source_node.inno_num || \
        is_circular_loop(source_node, target_node) || \
        link_already_exists(source_node, target_node):
      is_node_linked = true
    if !is_node_linked:
      unlinked_nodes.append(target_node)
  if !unlinked_nodes.empty():
    var final_target_node
    while final_target_node == null:
      for unlinked_node in unlinked_nodes:
        if random.randf() < float(1.0 / unlinked_nodes.size()):
          final_target_node = unlinked_node
          break
    return final_target_node
  else:
    return null



class Gene:
  var inno_num: int setget , get_inno_num

  func _init(_inno_num):
    inno_num = _inno_num

  func get_inno_num():
    return inno_num



class InputNode:
  extends Gene

  var name
  var outgoing_link_inno_nums
  # var outgoing_links = []

  func _init(_inno_num, _name="", _outgoing_link_inno_nums=[]).(_inno_num):
    name = _name
    outgoing_link_inno_nums = _outgoing_link_inno_nums

  func add_outgoing_link(link: Link):
    # outgoing_links.append(link)
    outgoing_link_inno_nums.append(link.inno_num)


class HiddenNode:
  extends Gene

  var name
  var incoming_link_inno_nums
  var outgoing_link_inno_nums
  # var incoming_links = []
  # var outgoing_links = []

  func _init(_inno_num, _name="",_incoming_link_inno_nums=[], _outgoing_link_inno_nums=[]).(_inno_num):
    name = _name
    incoming_link_inno_nums = _incoming_link_inno_nums
    outgoing_link_inno_nums = _outgoing_link_inno_nums

  func add_incoming_link(link: Link):
    # incoming_links.append(link)
    incoming_link_inno_nums.append(link.inno_num)

  func add_outgoing_link(link: Link):
    # outgoing_links.append(link)
    outgoing_link_inno_nums.append(link.inno_num)



class OutputNode:
  extends Gene

  var name
  var incoming_link_inno_nums
  # var incoming_links = []

  func _init(_inno_num, _name="", _incoming_link_inno_nums=[]).(_inno_num):
    name = _name
    incoming_link_inno_nums = _incoming_link_inno_nums

  func add_incoming_link(link: Link):
    incoming_link_inno_nums.append(link.inno_num)


class Link:
  extends Gene

  var weight: float
  var source_inno_num: int
  var target_inno_num: int
  var is_enabled: bool

  func _init(_inno_num, _weight,
      _source_inno_num, _target_inno_num, _is_enabled: bool).(_inno_num):
    inno_num = _inno_num
    weight = _weight
    source_inno_num = _source_inno_num
    target_inno_num = _target_inno_num
    is_enabled = _is_enabled

