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
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

# load OpenStudio measure libraries from openstudio-extension gem
require 'openstudio-extension'
require 'openstudio/extension/core/os_lib_helper_methods'

# start the measure
class TariffSelectionBlock < OpenStudio::Measure::EnergyPlusMeasure
  # human readable name
  def name
    return ' Tariff Selection-Block'
  end

  # human readable description
  def description
    return 'This measure sets block rates for electricity, and flat rates for gas, water, district heating, and district cooling.'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'Will add the necessary UtilityCost objects into the model.'
  end

  # define the arguments that the user will input
  def arguments(workspace)
    args = OpenStudio::Measure::OSArgumentVector.new

    # make choice argument for facade
    choices = OpenStudio::StringVector.new
    choices << 'QuarterHour'
    choices << 'HalfHour'
    choices << 'FullHour'
    # don't want to offer Day or Week even though valid E+ options
    # choices << "Day"
    # choices << "Week"
    demand_window_length = OpenStudio::Measure::OSArgument.makeChoiceArgument('demand_window_length', choices, true)
    demand_window_length.setDisplayName('Demand Window Length.')
    demand_window_length.setDefaultValue('QuarterHour')
    args << demand_window_length

    # adding argument for elec_rate
    elec_block_values = OpenStudio::Measure::OSArgument.makeStringArgument('elec_block_values', true)
    elec_block_values.setDisplayName('Electric Block Rate Ceiling Values')
    elec_block_values.setDescription('Comma separated block ceilings.')
    elec_block_values.setUnits('kWh')
    elec_block_values.setDefaultValue('200,1000')
    args << elec_block_values

    # adding argument for elec_rate
    elec_block_costs = OpenStudio::Measure::OSArgument.makeStringArgument('elec_block_costs', true)
    elec_block_costs.setDisplayName('Electric Block Rate Costs')
    elec_block_costs.setDescription('Comma separated block rate values. Should have same number of rates as blocks.')
    elec_block_costs.setUnits('$/kWh')
    elec_block_costs.setDefaultValue('0.07,0.06')
    args << elec_block_costs

    # adding argument for elec_rate
    elec_remaining_rate = OpenStudio::Measure::OSArgument.makeDoubleArgument('elec_remaining_rate', true)
    elec_remaining_rate.setDisplayName('Electric Rate for Remaining')
    elec_remaining_rate.setDescription('Rate for Electricity above last block level.')
    elec_remaining_rate.setUnits('$/kWh')
    elec_remaining_rate.setDefaultValue(0.05)
    args << elec_remaining_rate

    # adding argument for gas_rate
    gas_rate = OpenStudio::Measure::OSArgument.makeDoubleArgument('gas_rate', true)
    gas_rate.setDisplayName('Gas Rate')
    gas_rate.setUnits('$/therm')
    gas_rate.setDefaultValue(0.5)
    args << gas_rate

    # adding argument for water_rate
    water_rate = OpenStudio::Measure::OSArgument.makeDoubleArgument('water_rate', true)
    water_rate.setDisplayName('Water Rate')
    water_rate.setUnits('$/gal')
    water_rate.setDefaultValue(0.005)
    args << water_rate

    # adding argument for disthtg_rate
    disthtg_rate = OpenStudio::Measure::OSArgument.makeDoubleArgument('disthtg_rate', true)
    disthtg_rate.setDisplayName('District Heating Rate')
    disthtg_rate.setUnits('$/therm')
    disthtg_rate.setDefaultValue(0.2)
    args << disthtg_rate

    # adding argument for distclg_rate
    distclg_rate = OpenStudio::Measure::OSArgument.makeDoubleArgument('distclg_rate', true)
    distclg_rate.setDisplayName('District Cooling Rate')
    distclg_rate.setUnits('$/therm')
    distclg_rate.setDefaultValue(0.2)
    args << distclg_rate

    return args
  end

  # define what happens when the measure is run
  def run(workspace, runner, user_arguments)
    super(workspace, runner, user_arguments)

    # assign the user inputs to variables
    args = OsLib_HelperMethods.createRunVariables(runner, workspace, user_arguments, arguments(workspace))
    if !args then return false end

    # make arrays out of comma separated string inputs
    block_size_array = args['elec_block_values'].split(',')
    block_rate_array = args['elec_block_costs'].split(',')

    # throw error if size of blocks doesn't match size of rates
    if block_size_array.size != block_rate_array.size
      runner.registerError('The number of block rates should match the number of block sizes. This is excluding the renaming rate above the last block value.')
      return false
    end

    # throw error if block sizes don't get increasingly larger
    block_size = 0.0
    block_size_array.each do |block|
      if block.to_f <= block_size.to_f
        runner.registerError('Each block size should increase in size and be greater than 0.')
        return false
      else
        block_size = block
      end
    end

    # TODO: - throw error if block rates can't be converted to doubles

    # reporting initial condition of model
    starting_tariffs = workspace.getObjectsByType('UtilityCost:Tariff'.to_IddObjectType)
    runner.registerInitialCondition("The model started with #{starting_tariffs.size} tariff objects.")

    # map demand window length to integer
    demand_window_per_hour = nil
    if args['demand_window_length'] == 'QuarterHour'
      demand_window_per_hour = 4
    elsif args['demand_window_length'] == 'HalfHour'
      demand_window_per_hour = 2
    elsif args['demand_window_length'] == 'FullHour'
      demand_window_per_hour = 1
    end

    # make sure demand window length is is divisible by timestep
    if !workspace.getObjectsByType('Timestep'.to_IddObjectType).empty?
      initial_timestep = workspace.getObjectsByType('Timestep'.to_IddObjectType)[0].getString(0).get

      if initial_timestep.to_f / demand_window_per_hour.to_f == (initial_timestep.to_f / demand_window_per_hour.to_f).truncate # checks if remainder of divided numbers is > 0
        runner.registerInfo("The demand window length of a #{args['demand_window_length']} is compatible with the current setting of #{initial_timestep} timesteps per hour.")
      else
        workspace.getObjectsByType('Timestep'.to_IddObjectType)[0].setString(0, demand_window_per_hour.to_s)
        runner.registerInfo("Updating the timesteps per hour in the model from #{initial_timestep} to #{demand_window_per_hour} to be compatible with the demand window length of a #{args['demand_window_length']}")
      end
    else

      # add a timestep object to the workspace
      new_object_string = "
      Timestep,
        4;                                      !- Number of Timesteps per Hour
        "
      idfObject = OpenStudio::IdfObject.load(new_object_string)
      object = idfObject.get
      wsObject = workspace.addObject(object)
      new_object = wsObject.get
      runner.registerInfo('No timestep object found. Added a new timestep object set to 4 timesteps per hour')
    end

    # elec tariff object
    new_object_string = "
    UtilityCost:Tariff,
      Electricity Tariff,                     !- Name
      ElectricityPurchased:Facility,          !- Output Meter Name
      kWh,                                    !- Conversion Factor Choice
      ,                                       !- Energy Conversion Factor
      ,                                       !- Demand Conversion Factor
      ,                                       !- Time of Use Period Schedule Name
      ,                                       !- Season Schedule Name
      ,                                       !- Month Schedule Name
      Day,                                    !- Demand Window Length
      0.0;                                    !- Monthly Charge or Variable Name
      "
    elec_tariff = workspace.addObject(OpenStudio::IdfObject.load(new_object_string).get).get

    # make UtilityCost:Charge:Block object
    new_object_array = []
    new_object_array << "
    UtilityCost:Charge:Block,
      BlockEnergyCharge,            ! Charge Variable Name
      Electricity Tariff,           ! Tariff Name
      totalEnergy,                  ! Source Variable
      Annual,                       ! Season
      EnergyCharges,                ! Category Variable Name
      ,                             ! Remaining Into Variable
      ,                             ! Block Size Multiplier Value or Variable Name
      "

    # loop through blocks to extend array for new_object_string
    block_counter = 0
    block_size_array.each do |block_size|
      new_object_array << "
      #{block_size},                        ! Block Size #{block_counter + 1} Value or Variable Name
      #{block_rate_array[block_counter]},   ! Block #{block_counter + 1} Cost per Unit Value or Variable Name
      "
      block_counter += 1
    end

    new_object_array << "
      remaining,                        ! Block Size #{block_counter + 1} Value or Variable Name
      #{args['elec_remaining_rate']};   ! Block #{block_counter + 1} Cost per Unit Value or Variable Name
      "

    new_object_string = new_object_array.join('')
    elec_utility_cost = workspace.addObject(OpenStudio::IdfObject.load(new_object_string).get).get

    # gas tariff object
    if args['gas_rate'] > 0
      new_object_string = "
      UtilityCost:Tariff,
        Gas Tariff,                             !- Name
        NaturalGas:Facility,                    !- Output Meter Name
        Therm,                                  !- Conversion Factor Choice
        ,                                       !- Energy Conversion Factor
        ,                                       !- Demand Conversion Factor
        ,                                       !- Time of Use Period Schedule Name
        ,                                       !- Season Schedule Name
        ,                                       !- Month Schedule Name
        Day,                                    !- Demand Window Length
        0.0;                                    !- Monthly Charge or Variable Name
        "
      gas_tariff = workspace.addObject(OpenStudio::IdfObject.load(new_object_string).get).get

      # make UtilityCost:Charge:Simple objects for gas
      new_object_string = "
      UtilityCost:Charge:Simple,
        GasTariffEnergyCharge, !- Name
        Gas Tariff,                             !- Tariff Name
        totalEnergy,                            !- Source Variable
        Annual,                                 !- Season
        EnergyCharges,                          !- Category Variable Name
        #{args['gas_rate']};          !- Cost per Unit Value or Variable Name
        "
      gas_utility_cost = workspace.addObject(OpenStudio::IdfObject.load(new_object_string).get).get
    end

    # conversion for water tariff rate
    dollars_per_gallon = args['water_rate']
    dollars_per_meter_cubed = OpenStudio.convert(dollars_per_gallon, '1/gal', '1/m^3').get

    # water tariff object
    if args['water_rate'] > 0
      new_object_string = "
      UtilityCost:Tariff,
        Water Tariff,                             !- Name
        Water:Facility,             !- Output Meter Name
        UserDefined,                            !- Conversion Factor Choice
        1,                                       !- Energy Conversion Factor
        ,                                       !- Demand Conversion Factor
        ,                                       !- Time of Use Period Schedule Name
        ,                                       !- Season Schedule Name
        ,                                       !- Month Schedule Name
        ,                                       !- Demand Window Length
        0.0;                                    !- Monthly Charge or Variable Name
        "
      water_tariff = workspace.addObject(OpenStudio::IdfObject.load(new_object_string).get).get

      # make UtilityCost:Charge:Simple objects for water
      new_object_string = "
      UtilityCost:Charge:Simple,
        WaterTariffEnergyCharge, !- Name
        Water Tariff,                             !- Tariff Name
        totalEnergy,                             !- Source Variable
        Annual,                                 !- Season
        EnergyCharges,                          !- Category Variable Name
        #{dollars_per_meter_cubed};          !- Cost per Unit Value or Variable Name
        "
      water_utility_cost = workspace.addObject(OpenStudio::IdfObject.load(new_object_string).get).get
    end

    # disthtg tariff object
    if args['disthtg_rate'] > 0
      new_object_string = "
      UtilityCost:Tariff,
        DistrictHeating Tariff,                             !- Name
        DistrictHeating:Facility,                           !- Output Meter Name
        Therm,                                  !- Conversion Factor Choice
        ,                                       !- Energy Conversion Factor
        ,                                       !- Demand Conversion Factor
        ,                                       !- Time of Use Period Schedule Name
        ,                                       !- Season Schedule Name
        ,                                       !- Month Schedule Name
        Day,                                    !- Demand Window Length
        0.0;                                    !- Monthly Charge or Variable Name
        "
      disthtg_tariff = workspace.addObject(OpenStudio::IdfObject.load(new_object_string).get).get

      # make UtilityCost:Charge:Simple objects for disthtg
      new_object_string = "
      UtilityCost:Charge:Simple,
        DistrictHeatingTariffEnergyCharge, !- Name
        DistrictHeating Tariff,                             !- Tariff Name
        totalEnergy,                            !- Source Variable
        Annual,                                 !- Season
        EnergyCharges,                          !- Category Variable Name
        #{args['disthtg_rate']};          !- Cost per Unit Value or Variable Name
        "
      disthtg_utility_cost = workspace.addObject(OpenStudio::IdfObject.load(new_object_string).get).get
    end

    # distclg tariff object
    if args['distclg_rate'] > 0
      new_object_string = "
      UtilityCost:Tariff,
        DistrictCooling Tariff,                             !- Name
        DistrictCooling:Facility,                           !- Output Meter Name
        Therm,                                  !- Conversion Factor Choice
        ,                                       !- Energy Conversion Factor
        ,                                       !- Demand Conversion Factor
        ,                                       !- Time of Use Period Schedule Name
        ,                                       !- Season Schedule Name
        ,                                       !- Month Schedule Name
        Day,                                    !- Demand Window Length
        0.0;                                    !- Monthly Charge or Variable Name
        "
      distclg_tariff = workspace.addObject(OpenStudio::IdfObject.load(new_object_string).get).get

      # make UtilityCost:Charge:Simple objects for distclg
      new_object_string = "
      UtilityCost:Charge:Simple,
        DistrictCoolingTariffEnergyCharge, !- Name
        DistrictCooling Tariff,                             !- Tariff Name
        totalEnergy,                            !- Source Variable
        Annual,                                 !- Season
        EnergyCharges,                          !- Category Variable Name
        ['distclg_rate'];          !- Cost per Unit Value or Variable Name
      "
      distclg_utility_cost = workspace.addObject(OpenStudio::IdfObject.load(new_object_string).get).get
    end

    # report final condition of model
    finishing_tariffs = workspace.getObjectsByType('UtilityCost:Tariff'.to_IddObjectType)
    runner.registerFinalCondition("The model finished with #{finishing_tariffs.size} tariff objects.")

    return true
  end
end

# register the measure to be used by the application
TariffSelectionBlock.new.registerWithApplication
