require 'spec_helper'

# Test behavior of HLModel::Process created with
# DSL new_process statement
describe "HLModel::Process created with DSL#new_process" do

  let :model do
    RBSim.dsl do
      new_process :worker do
        with_event :data do |volume|
          delay_for 200
          cpu do |c|
            20/c.performance
          end
        end
        delay_for 100
        cpu do |cpu|
          100/cpu.performance
        end
        new_process :child do
          delay_for 400
        end
        register_event :data, 1000
        send_data to: :child, size: 1024, type: :hello, content: "Hello!"
        log "finished main, will serve events"
      end
    end
  end

  let :process do
    p = model.processes[:worker]
    p.node = :node01
    p
  end

  module NewProcessSpec
    class CPU
      def performance
        20
      end
    end
  end

  it "has correct behavior" do
    expect(model.processes.size).to eq(1)

    event = process.serve_system_event :delay_for
    expect(event).to eq({name: :delay_for, args: { time: 100 }})

    event = process.serve_system_event :cpu
    expect(event[:name]).to eq(:cpu)
    # CPU time computed for specified CPU
    expect(event[:args][:block].call NewProcessSpec::CPU.new).to eq(5)

    # new process
    event = process.serve_system_event :new_process
    new_process = event[:args][:constructor].call event[:args][:constructor_args]
    expect(model.processes.size).to eq(2)
    expect(model.processes[:child]).not_to be_nil
    expect(model.processes[:child]).to eq(new_process)
    # serve event of the new process
    event = new_process.serve_system_event :delay_for
    expect(event).to eq({name: :delay_for, args: { time: 400 }})


    # old process again
    # user event registered, its handler will be run in the
    # future when time comes
    p = process.serve_user_event
    expect(p).to eq(process) # returns modified process
    expect(process.event_queue_size).to eq(4)

    # send_data
    event = process.serve_system_event :send_data
    expect(event[:name]).to eq(:send_data)
    # CPU time computed for specified CPU
    expect(event[:args]).to eq(to: :child, size: 1024, type: :hello, content: "Hello!")

    # log
    event = process.serve_system_event :log
    expect(event[:name]).to eq(:log)
    expect(event[:args]).to eq("finished main, will serve events")


    # Events created by serving the the :data user event above follow:

    event = process.serve_system_event :delay_for
    expect(event).to eq({name: :delay_for, args: { time: 200 }})

    event = process.serve_system_event :cpu
    expect(event[:name]).to eq(:cpu)
    # CPU time computed for specified CPU
    expect(event[:args][:block].call NewProcessSpec::CPU.new).to eq(1)


  end

end
