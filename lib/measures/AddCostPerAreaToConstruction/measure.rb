# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2022, Alliance for Sustainable Energy, LLC.
# All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# (1) Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# (2) Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# (3) Neither the name of the copyright holder nor the names of any contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission from the respective party.
#
# (4) Other than as required in clauses (1) and (2), distributions in any form
# of modifications or other derivative works may not use the "OpenStudio"
# trademark, "OS", "os", or any other confusingly similar designation without
# specific prior written permission from Alliance for Sustainable Energy, LLC.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER(S) AND ANY CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER(S), ANY CONTRIBUTORS, THE
# UNITED STATES GOVERNMENT, OR THE UNITED STATES DEPARTMENT OF ENERGY, NOR ANY OF
# THEIR EMPLOYEES, BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
# OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# *******************************************************************************

# see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

# see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/model/html/namespaces.html

# start the measure
class AddCostPerAreaToConstruction < OpenStudio::Measure::ModelMeasure
  # define the name that a user will see, this method may be deprecated as
  # the display name in PAT comes from the name field in measure.xml
  def name
    return 'Add Cost per Area to Construction'
  end

  # human readable description
  def description
    return 'This measure will create life cycle cost objects associated with the selected construction. You can set a material and installation cost, demolition cost, and O&M costs. Optionally existing cost objects already associated with building can be deleted. This measure will not affect energy use of the building.'
  end

  # human readable description of modeling approach
  def modeler_description
    return "In addition to the inputs for the cost values, a number of other inputs are exposed to specify when the cost first occurs and at what frequency it occurs in the future. This measure is intended to be used as an 'Always Run' measure to apply costs to the baseline simulation before any design alternatives manipulate it.

For baseline costs, 'Years Until Costs Start' indicates the year that the capital costs first occur. For new construction this will be typically be 0 and 'Demolition Costs Occur During Initial Construction' will be 'false'. For a retrofit 'Years Until Costs Start' is between 0 and the 'Expected Life' of the object, while 'Demolition Costs Occur During Initial Construction' is true.  O&M cost and frequency can be whatever is appropriate for the component."
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # populate choice argument for constructions that are applied to surfaces in the model
    construction_handles = OpenStudio::StringVector.new
    construction_display_names = OpenStudio::StringVector.new

    # putting space types and names into hash
    construction_args = model.getConstructions
    construction_args_hash = {}
    construction_args.each do |construction_arg|
      construction_args_hash[construction_arg.name.to_s] = construction_arg
    end

    # looping through sorted hash of constructions
    construction_args_hash.sort.map do |key, value|
      # only include if construction is used on surface
      if value.getNetArea > 0
        construction_handles << value.handle.to_s
        construction_display_names << key
      end
    end

    # make an argument for construction
    # todo - update this to allow all roofs, all exterior walls, all exterior windows
    construction = OpenStudio::Measure::OSArgument.makeChoiceArgument('construction', construction_handles, construction_display_names, true)
    construction.setDisplayName('Choose a Construction to Add Costs to')
    args << construction

    # make an argument to remove existing costs
    remove_costs = OpenStudio::Measure::OSArgument.makeBoolArgument('remove_costs', true)
    remove_costs.setDisplayName('Remove Existing Costs')
    remove_costs.setDefaultValue(true)
    args << remove_costs

    # make an argument for material and installation cost
    material_cost_ip = OpenStudio::Measure::OSArgument.makeDoubleArgument('material_cost_ip', true)
    material_cost_ip.setDisplayName('Material and Installation Costs for Construction per Area Used')
    material_cost_ip.setUnits('$/ft^2')
    material_cost_ip.setDefaultValue(0.0)
    args << material_cost_ip

    # make an argument for demolition cost
    demolition_cost_ip = OpenStudio::Measure::OSArgument.makeDoubleArgument('demolition_cost_ip', true)
    demolition_cost_ip.setDisplayName('Demolition Costs for Construction per Area Used')
    demolition_cost_ip.setUnits('$/ft^2')
    demolition_cost_ip.setDefaultValue(0.0)
    args << demolition_cost_ip

    # make an argument for duration in years until costs start
    years_until_costs_start = OpenStudio::Measure::OSArgument.makeIntegerArgument('years_until_costs_start', true)
    years_until_costs_start.setDisplayName('Years Until Costs Start')
    years_until_costs_start.setUnits('whole years')
    years_until_costs_start.setDefaultValue(0)
    args << years_until_costs_start

    # make an argument to determine if demolition costs should be included in initial construction
    demo_cost_initial_const = OpenStudio::Measure::OSArgument.makeBoolArgument('demo_cost_initial_const', true)
    demo_cost_initial_const.setDisplayName('Demolition Costs Occur During Initial Construction')
    demo_cost_initial_const.setDefaultValue(false)
    args << demo_cost_initial_const

    # make an argument for expected life
    expected_life = OpenStudio::Measure::OSArgument.makeIntegerArgument('expected_life', true)
    expected_life.setDisplayName('Expected Life')
    expected_life.setUnits('whole years')
    expected_life.setDefaultValue(20)
    args << expected_life

    # make an argument for o&m cost
    om_cost_ip = OpenStudio::Measure::OSArgument.makeDoubleArgument('om_cost_ip', true)
    om_cost_ip.setDisplayName('O & M Costs for Construction per Area Used')
    om_cost_ip.setUnits('$/ft^2')
    om_cost_ip.setDefaultValue(0.0)
    args << om_cost_ip

    # make an argument for o&m frequency
    om_frequency = OpenStudio::Measure::OSArgument.makeIntegerArgument('om_frequency', true)
    om_frequency.setDisplayName('O & M Frequency')
    om_frequency.setUnits('whole years')
    om_frequency.setDefaultValue(1)
    args << om_frequency

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    construction = runner.getOptionalWorkspaceObjectChoiceValue('construction', user_arguments, model) # model is passed in because of argument type
    remove_costs = runner.getBoolArgumentValue('remove_costs', user_arguments)
    material_cost_ip = runner.getDoubleArgumentValue('material_cost_ip', user_arguments)
    demolition_cost_ip = runner.getDoubleArgumentValue('demolition_cost_ip', user_arguments)
    years_until_costs_start = runner.getIntegerArgumentValue('years_until_costs_start', user_arguments)
    demo_cost_initial_const = runner.getBoolArgumentValue('demo_cost_initial_const', user_arguments)
    expected_life = runner.getIntegerArgumentValue('expected_life', user_arguments)
    om_cost_ip = runner.getDoubleArgumentValue('om_cost_ip', user_arguments)
    om_frequency = runner.getIntegerArgumentValue('om_frequency', user_arguments)

    # check the construction for reasonableness
    if construction.empty?
      handle = runner.getStringArgumentValue('construction', user_arguments)
      if handle.empty?
        runner.registerError('No construction was chosen.')
      else
        runner.registerError("The selected construction with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
      end
      return false
    else
      if !construction.get.to_Construction.empty?
        construction = construction.get.to_Construction.get
      else
        runner.registerError('Script Error - argument not showing up as construction.')
        return false
      end
    end

    # set flags to use later
    costs_requested = false
    costs_removed = false

    # check costs for reasonableness
    if material_cost_ip.abs + demolition_cost_ip.abs + om_cost_ip.abs == 0
      runner.registerInfo("No costs were requested for #{construction.name}.")
    else
      costs_requested = true
    end

    # check lifecycle arguments for reasonableness
    if (years_until_costs_start < 0) && (years_until_costs_start > expected_life)
      runner.registerError('Years until costs start should be a non-negative integer less than Expected Life.')
    end
    if (expected_life < 1) && (expected_life > 100)
      runner.registerError('Choose an integer greater than 0 and less than or equal to 100 for Expected Life.')
    end
    if om_frequency < 1
      runner.registerError('Choose an integer greater than 0 for O & M Frequency.')
    end

    # short def to make numbers pretty (converts 4125001.25641 to 4,125,001.26 or 4,125,001). The definition be called through this measure
    def neat_numbers(number, roundto = 2) # round to 0 or 2)
      if roundto == 2
        number = format '%.2f', number
      else
        number = number.round
      end
      # regex to add commas
      number.to_s.reverse.gsub(/([0-9]{3}(?=([0-9])))/, '\\1,').reverse
    end

    # reporting initial condition of model
    runner.registerInitialCondition("Construction #{construction.name} has #{construction.lifeCycleCosts.size} lifecycle cost objects.")

    # remove any component cost line items associated with the construction.
    if !construction.lifeCycleCosts.empty? && (remove_costs == true)
      runner.registerInfo("Removing existing lifecycle cost objects associated with #{construction.name}")
      removed_costs = construction.removeLifeCycleCosts
      costs_removed = !removed_costs.empty?
    end

    # show as not applicable if no cost requested and if no costs removed
    if (costs_requested == false) && (costs_removed == false)
      runner.registerAsNotApplicable('No new lifecycle costs objects were requested, and no costs were deleted.')
    end

    # add lifeCycleCost objects if there is a non-zero value in one of the cost arguments
    if costs_requested == true

      # converting doubles to si values from ip
      material_cost_si = OpenStudio.convert(OpenStudio::Quantity.new(material_cost_ip, OpenStudio.createUnit('1/ft^2').get), OpenStudio.createUnit('1/m^2').get).get.value
      demolition_cost_si = OpenStudio.convert(OpenStudio::Quantity.new(demolition_cost_ip, OpenStudio.createUnit('1/ft^2').get), OpenStudio.createUnit('1/m^2').get).get.value
      om_cost_si = OpenStudio.convert(OpenStudio::Quantity.new(om_cost_ip, OpenStudio.createUnit('1/ft^2').get), OpenStudio.createUnit('1/m^2').get).get.value

      # adding new cost items
      lcc_mat = OpenStudio::Model::LifeCycleCost.createLifeCycleCost("LCC_Mat - #{construction.name}", construction, material_cost_si, 'CostPerArea', 'Construction', expected_life, years_until_costs_start)
      if demo_cost_initial_const
        lcc_demo = OpenStudio::Model::LifeCycleCost.createLifeCycleCost("LCC_Demo - #{construction.name}", construction, demolition_cost_si, 'CostPerArea', 'Salvage', expected_life, years_until_costs_start)
      else
        lcc_demo = OpenStudio::Model::LifeCycleCost.createLifeCycleCost("LCC_Demo - #{construction.name}", construction, demolition_cost_si, 'CostPerArea', 'Salvage', expected_life, years_until_costs_start + expected_life)
      end
      lcc_om = OpenStudio::Model::LifeCycleCost.createLifeCycleCost("LCC_OM - #{construction.name}", construction, om_cost_si, 'CostPerArea', 'Maintenance', om_frequency, 0)

    end

    # loop through lifecycle costs getting total costs under "Construction category"
    const_LCCs = construction.lifeCycleCosts
    const_total_mat_cost = 0
    const_LCCs.each do |const_LCC|
      if const_LCC.category == 'Construction'
        const_total_mat_cost += const_LCC.totalCost
      end
    end

    # reporting final condition of model
    if !construction.lifeCycleCosts.empty?
      costed_area_ip = OpenStudio.convert(OpenStudio::Quantity.new(construction.lifeCycleCosts[0].costedArea.get, OpenStudio.createUnit('m^2').get), OpenStudio.createUnit('ft^2').get).get.value
      runner.registerFinalCondition("A new lifecycle cost object was added to construction #{construction.name} with an area of #{neat_numbers(costed_area_ip, 0)} (ft^2). Material and Installation costs are $#{neat_numbers(const_total_mat_cost, 0)}.")
    else
      runner.registerFinalCondition("There are no lifecycle cost objects associated with construction #{construction.name}.")
    end

    return true
  end
end

# this allows the measure to be used by the application
AddCostPerAreaToConstruction.new.registerWithApplication
