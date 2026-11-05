
# PROBLEMA 2: Planificacion de tareas con dependencias
# PASO 1: structs + lectura de tareas.csv
# PASO 2: busqueda recursiva de ordenes y penalizacion


# Las structs %Tarea{} y %Plan{} estan en Tarea.ex y Plan.ex

defmodule Tareas do

  # Devuelve {tareas, errores}
  #   tareas  = lista de {%Tarea{}, numero_de_linea}
  #   errores = lista de {numero_de_linea, motivo}

  def leer_tareas(ruta) do
    if File.exists?(ruta) do
      {tareas, errores} =
        ruta
        |> Util2.lineas_utiles()
        |> Stream.map(fn {linea, i} -> {parsear_linea(linea), i} end)
        |> Enum.reduce({[], []}, fn {resultado, i}, {tareas, errores} ->
          case resultado do
            # [x | lista] pone x al inicio de la lista
            {:ok, tarea} -> {[{tarea, i} | tareas], errores}
            {:error, motivo} -> {tareas, [{i, motivo} | errores]}
          end
        end)

      {:ok, Enum.reverse(tareas), Enum.reverse(errores)}
    else
      {:error, "no existe el archivo #{ruta}"}
    end
  end


  # Convierte el texto "B;2;5;A" en un %Tarea{}
  # Cada paso devuelve {:ok, dato} o {:error, motivo}

  def parsear_linea(linea) do
    with {:ok, [id, sd, sp, sdeps]} <- partir(linea),
         {:ok, id} <- validar_id(id),
         {:ok, duracion} <- entero(sd, "duracion"),
         {:ok, plazo} <- entero(sp, "plazo") do
      {:ok, Tarea.crear(id, duracion, plazo, parsear_deps(sdeps))}
    else
      # si cualquier paso fallo, devolvemos su error
      {:error, motivo} -> {:error, motivo}
    end
  end

  defp partir(linea) do
    case String.split(linea, ";") do
      [_, _, _, _] = campos -> {:ok, campos}
      campos -> {:error, "se esperaban 4 campos separados por ; y hay #{length(campos)}"}
    end
  end

  defp validar_id(texto) do
    id = String.trim(texto)

    cond do
      id == "" -> {:error, "el id esta vacio"}
      String.contains?(id, "|") -> {:error, "el id no puede contener |"}
      true -> {:ok, id}
    end
  end

  defp entero(texto, nombre) do
    case Integer.parse(String.trim(texto)) do
      {n, ""} -> {:ok, n}
      _ -> {:error, "#{nombre} no es un entero: #{inspect(texto)}"}
    end
  end

  # "-" significa sin dependencias; "B|C" -> ["B", "C"]
  defp parsear_deps(texto) do
    t = String.trim(texto)

    if t == "-" do
      []
    else
      t |> String.split("|") |> Enum.map(fn dep -> String.trim(dep) end)
    end
  end

  # ==========================================================
  # PASO 2: BUSQUEDA RECURSIVA DE PLANES
  # Es el mismo estilo del generador de parentesis: un Stream
  # perezoso que prueba cada opcion y retrocede.
  # ==========================================================

  # Devuelve un Stream de %Plan{}, uno por cada orden valido
  def planes(tareas) do
    buscar(tareas, [], [], [], 0, 0)
  end

  # Caso base: no quedan tareas pendientes -> plan completo.
  # orden y fins se fueron armando al reves, por eso el reverse.
  defp buscar([], _terminadas, orden, fins, _tiempo, penalizacion) do
    [Plan.crear(Enum.reverse(orden), Enum.reverse(fins), penalizacion)]
  end

  # Caso recursivo: probar cada tarea habilitada, en orden alfabetico
  defp buscar(pendientes, terminadas, orden, fins, tiempo, penalizacion) do
    Stream.flat_map(habilitadas(pendientes, terminadas), fn tarea ->
      fin = tiempo + tarea.duracion
      atraso = max(0, fin - tarea.plazo)

      buscar(
        List.delete(pendientes, tarea),
        [tarea.id | terminadas],
        [tarea.id | orden],
        [{tarea.id, fin} | fins],
        fin,
        penalizacion + atraso
      )
    end)
  end

  # Tareas pendientes con todas sus dependencias terminadas,
  # ordenadas alfabeticamente por id
  defp habilitadas(pendientes, terminadas) do
    pendientes
    |> Util2.aplicar_filtro(fn tarea -> cumplidas?(tarea.dependencias, terminadas) end)
    |> Util2.ordenar(:asc, & &1.id)
  end

  # Recursion: ¿todas las dependencias estan en la lista de terminadas?
  defp cumplidas?([], _terminadas), do: true

  defp cumplidas?([dep | resto], terminadas) do
    if dep in terminadas do
      cumplidas?(resto, terminadas)
    else
      false
    end
  end


  # MAIN

  def main do
    case leer_tareas("tareas.csv") do
      {:error, motivo} ->
        Util2.mostrar("AVISO: #{motivo}", :error)

      {:ok, _tareas, errores} when errores != [] ->
        errores
        |> Util2.convertir_coleccion_mensaje(fn {i, motivo} -> "  ERROR linea #{i}: #{motivo}\n" end)
        |> Util2.mostrar(:error)

        Util2.mostrar("No se buscan planes: hay errores en la entrada", :mensaje)

      {:ok, [], []} ->
        Util2.mostrar("Proyecto vacio: no hay tareas", :mensaje)

      {:ok, lista, []} ->
        tareas = Enum.map(lista, fn {tarea, _linea} -> tarea end)
        mostrar_planes(tareas)
    end
  end

  defp mostrar_planes(tareas) do
    total =
      Enum.reduce(planes(tareas), 0, fn plan, cont ->
        Util2.mostrar("  #{cont + 1}. #{plan}", :mensaje)
        cont + 1
      end)

    duracion_total = tareas |> Enum.map(fn t -> t.duracion end) |> Enum.sum()

    Util2.mostrar("Total de planes: #{total}", :mensaje)
    Util2.mostrar("Tiempo total del proyecto: #{duracion_total}", :mensaje)
  end
end

Tareas.main()
