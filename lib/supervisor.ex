defmodule IaqSensor.Supervisor do
  @moduledoc """
  iAQ Sensor Supervisor
  """

  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    children = [
      IaqSensor.Device,
    ]

    opts = [strategy: :one_for_one]
    Supervisor.init(children, opts)
  end

end
