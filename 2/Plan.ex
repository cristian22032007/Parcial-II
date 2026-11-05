defmodule Plan do
  defstruct orden: [], finalizaciones: [], penalizacion: 0

  def crear(orden, finalizaciones, penalizacion) do
    %Plan{
      orden: orden,
      finalizaciones: finalizaciones,
      penalizacion: penalizacion
    }
  end

  # Define como se convierte un Plan en texto: "#{plan}"
  defimpl String.Chars, for: Plan do
    def to_string(%Plan{orden: orden, penalizacion: penalizacion}) do
      "#{Enum.join(orden, " - ")} (penalizacion #{penalizacion})"
    end
  end
end
