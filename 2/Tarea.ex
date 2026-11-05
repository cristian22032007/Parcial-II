defmodule Tarea do
  defstruct id: "", duracion: 0, plazo: 0, dependencias: []

  def crear(id, duracion, plazo, dependencias) do
    %Tarea{
      id: id,
      duracion: duracion,
      plazo: plazo,
      dependencias: dependencias
    }
  end

  # Define como se convierte una Tarea en texto: "#{tarea}"
  defimpl String.Chars, for: Tarea do
    def to_string(%Tarea{id: id, duracion: duracion, plazo: plazo, dependencias: deps}) do
      dependencias = if deps == [], do: "ninguna", else: Enum.join(deps, ", ")

      "#{id}: dura #{duracion}, plazo #{plazo}, depende de #{dependencias}"
    end
  end
end
