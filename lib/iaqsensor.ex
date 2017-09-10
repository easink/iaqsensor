defmodule IaqSensor do
  @moduledoc """
  Documentation for Iaqsensor.
  """
  use Application

  def start(_type, _args) do
    IaqSensor.Supervisor.start_link()
  end

  def update() do
    IaqSensor.Device.update()
  end

end
