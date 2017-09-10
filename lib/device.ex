defmodule IaqSensor.Device do
  @moduledoc """
  IaqSensor Device
  """
  use GenServer
  use Bitwise
  require Logger
  require IEx

  @vendor_id 1003
  @product_id 8211

  @type1_seq_start 1
  @type2_seq_start 103

  defmodule State do
    @moduledoc false
    defstruct [:hid_dev, :type1_seq, :type2_seq]
  end

  def start_link(state \\ []) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    # open HID
    {:ok, dev} = HID.open(@vendor_id, @product_id)
    {_, seq} = do_type1(dev, "*IDN?", @type1_seq_start)
    {_, seq} = do_type1(dev, "KNOBPRE?", seq)
    {_, seq} = do_type1(dev, "WFMPRE?", seq)
    {_, seq} = do_type1(dev, "FLAGS?", seq)
    {:ok, %State{hid_dev: dev, type1_seq: seq, type2_seq: @type2_seq_start}}
  end

  # API

  def update() do
    GenServer.call(__MODULE__, {:update})
  end

  # callbacks

  def handle_call({:update}, _from, state) do
    type1_seq = state.type1_seq
    type2_seq = state.type2_seq

    dev = state.hid_dev
    {_, type1_seq} = do_type1(dev, "FLAGGET?", type1_seq)
    {msg, type2_seq} = do_type2(dev, "*TR", type2_seq)
    <<"@", _seq, ppm::little-16, _pwm::little-16, _rh::little-16, _rs::little-32, rest::binary>> = msg
    # IO.puts(inspect([_seq, ppm, _pwm, _rh, _rs, rest]))
    {:reply, ppm, %{state | type1_seq: type1_seq, type2_seq: type2_seq}}
  end

  # private

  defp do_type1(dev, msg, seq) do
    data = <<"@", format_seq1(seq)::binary, msg::binary, "\n">>
    pad = 16 - byte_size(data)
    data = data <> String.duplicate("@", pad)
    Logger.debug fn ->
      "Write '#{inspect data}'"
    end
    {:ok, _} = HID.write(dev, data)
    {:ok, msg} = hid_read(dev)
    Logger.debug fn ->
      "Read '#{inspect msg}'"
    end
    {msg, seq + 1 &&& 0xffff}
  end

  defp do_type2(dev, msg, seq) do
    data = <<"@", format_seq2(seq)::binary, msg::binary, "\n">>
    pad = 16 - byte_size(data)
    data = data <> String.duplicate("@", pad)
    Logger.debug fn ->
      "Write '#{inspect data}'"
    end
    {:ok, _} = HID.write(dev, data)
    {:ok, msg} = hid_read(dev)
    Logger.debug fn ->
      "Read '#{inspect msg}'"
    end
    {msg, ((seq + 1 &&& 0xff) || @type2_seq_start)}
  end

  defp hid_read(dev, data \\ "") do
    case HID.read(dev, 1000) do
      {:ok, ""}  -> {:ok, data}
      {:ok, msg} -> hid_read(dev, data <> msg)
    end
  end

  defp format_seq1(seq) do
    new_seq = seq &&& 0xffff
    new_seq
    |> Integer.to_string(16)
    |> String.pad_leading(4, "0")
  end

  defp format_seq2(seq) do
    <<seq::8>>
  end
end
