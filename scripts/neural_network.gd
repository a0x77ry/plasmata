class_name NeuralNetwork

const INPUT_INCREMENT := 0.01
const NO_IN := -1
const THRESHOLD := 1.0
const E = 2.7182
const USE_BIAS = false

var random = RandomNumberGenerator.new()
var input_layer = [] 
var output_layer = [] 
var hidden_layer = [] 
var links = []
# var thread = Thread.new()

var genome
# var starting_link_id: int

func _init(_genome):
  genome = _genome
  # starting_link_id = _starting_link_id
  random.randomize()

  # Create the NEAT bias node
  if USE_BIAS:
    input_layer.append(InputNode.new(0, "bias", 1.0))

  # Create nodes according to the genome (set in agent.gd)
  for input_node_gene in genome.input_nodes:
    var i_node = InputNode.new(input_node_gene.inno_num, input_node_gene.name)
    input_layer.append(i_node)

  for hidden_node_gene in genome.hidden_nodes:
    var h_node = HiddenNode.new(hidden_node_gene.inno_num)
    hidden_layer.append(h_node)

  for output_node_gene in genome.output_nodes:
    var o_node = OutputNode.new(output_node_gene.inno_num, output_node_gene.name)
    output_layer.append(o_node)

  var all_nodes = input_layer + hidden_layer + output_layer

  # Create the links between the nodes using genome
  for link in genome.links:
    var source_node
    var target_node
    for node in all_nodes:
      var nin = node.inno_num
      if nin == link.source_inno_num:
        source_node = node
      elif nin == link.target_inno_num:
        target_node = node
    if (source_node != null) && (target_node != null):
      var link_instance = Link.new(link.inno_num, source_node, target_node,
          link.weight,
          link.source_inno_num,
          link.target_inno_num, true)
      links.append(link_instance)


# func connect_nn_layers(source_layer, target_layer):
#   var i := starting_link_id
#   for s_node in source_layer:
#     for t_node in target_layer:
#       var new_link = Link.new(i, s_node, t_node,
#           random.randf_range(-ORIGINAL_WEIGHT_VALUE_LIMIT, ORIGINAL_WEIGHT_VALUE_LIMIT),
#           s_node.id, t_node.id, true)
#       # Main.add_UID_in_used(i)
#       if i > Main.max_id_used:
#         Main.generate_UID()
#       i += 1
#       links.append(new_link)
#       genome["links"].append({"id": new_link.id,
#           "weight": new_link.weight, "source_id": new_link.source_node.id,
#           "target_id": new_link.target_node.id, "is_enabled": true})
#       # add incoming_link_ids and outgoing_link_ids to the nodes involved
#       var all_genome_nodes = genome["input_nodes"] \
#           + genome["hidden_nodes"] \
#           + genome["output_nodes"]
#       for _genome_node in all_genome_nodes:
#         if _genome_node["id"] == new_link.source_node.id:
#           _genome_node["outgoing_link_ids"].append(new_link.id)
#         elif _genome_node["id"] == new_link.target_node.id:
#           _genome_node["incoming_link_ids"].append(new_link.id)


func set_input(input_dict: Dictionary):
  for node in input_layer:
    if node.name != "bias":
      node.set_value(input_dict[node.get_name()])


func get_output() -> Dictionary:
  # thread.start(self, "get_out")
  # var res = thread.wait_to_finish()
  # return res
  return get_out(null) # parameter needed for thread compatibility

func get_out(_userdata) -> Dictionary:
  # Reset all calculated values
  var calculatable_nodes = hidden_layer + links
  for node in calculatable_nodes:
    node.reset_calculated()

  var output_dict = {}
  for node in output_layer:
    var node_name = node.get_name()
    output_dict[node_name] = node.get_value()

  return output_dict


func disolve_nn():
  for node in input_layer:
    node.outgoing_links = []

  for node in hidden_layer:
    node.incoming_links = []
    node.outgoing_links = []

  for node in output_layer:
    node.incoming_links = []

  for link in links:
    link.source_node = null
    link.target_node = null


class NNNode:
  var name: String setget ,get_name
  var inno_num: int setget , get_inno_num


  func _init(_inno_num, _name=""):
    name = _name
    inno_num = _inno_num


  func get_name():
    return name

  func get_inno_num():
    return inno_num

  func _relu(val):
    return 0 if val <= 0 else val

  func _sigmoid(val):
    return 1 / (1 + pow(E, -val))

  func _tanh(val):
    return (2.0 / (1.0 + pow(E, -2.0 * val))) - 1.0



class InputNode:
  extends NNNode

  var value: float setget set_value, get_value
  var outgoing_links = []

  func _init(_inno_num, _name, _value=randf()).(_inno_num, _name):
    value = _value 

  func set_value(_value):
    value = _value

  func get_value():
    return value

  func add_outgoing_link(link: Link):
    outgoing_links.append(link)



class OutputNode:
  extends NNNode

  var incoming_links = []
  var value: float


  func _init(_inno_num, _name="", _value=randf()).(_inno_num, _name):
    name = _name
    value = _value


  func get_value():
    var _value := 0.0
    for link in incoming_links:
      if link.is_enabled:
        _value += link.get_value()
    return _value


  func add_incoming_link(link: Link):
    incoming_links.append(link)


  func get_normalized_threshold():
    # return (incoming_links.size() / 2.0) as float
    return THRESHOLD



class HiddenNode:
  extends NNNode

  var incoming_links = []
  var outgoing_links = []
  var value: float
  var is_calculated: float


  func _init(_inno_num, _name="", _value=randf(), _is_calculated=false).(_inno_num, _name):
    value = _value
    name = _name
    is_calculated = _is_calculated

  func get_value():
    if !is_calculated:
      var _value := 0.0
      for link in incoming_links:
        if link.is_enabled:
          _value += link.get_value()
      value = _value
      is_calculated = true
      return _value
    else:
      return value


  func add_incoming_link(link: Link):
    incoming_links.append(link)


  func add_outgoing_link(link: Link):
    outgoing_links.append(link)

  func reset_calculated():
    is_calculated = false


class Link:
  var inno_num: int
  var source_node: NNNode
  var target_node: NNNode
  var weight: float
  var source_inno_num: int
  var target_inno_num: int
  var is_enabled: bool
  var is_calculated: float
  var value


  func _init(_inno_num, _source_node: NNNode, _target_node: NNNode, _weight,
      _source_inno_num, _target_inno_num, _is_enabled: bool, _is_calculated: bool=false):
    if _inno_num == NO_IN:
      print("Error in NN: no IN in link")
      # inno_num = population.generate_UID()
    else:
      inno_num = _inno_num
    source_node = _source_node
    target_node = _target_node
    weight = _weight
    source_inno_num = _source_inno_num
    target_inno_num = _target_inno_num
    is_enabled = _is_enabled
    is_calculated = _is_calculated

    source_node.add_outgoing_link(self)
    target_node.add_incoming_link(self)


  func get_value():
    if !is_calculated:
      var val = source_node.get_value()
      val = val * weight
      value = val
      is_calculated = true
      return val
    else:
      print("Link calculated: %s" % value)
      return value

  func reset_calculated():
    is_calculated = false

