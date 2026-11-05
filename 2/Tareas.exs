Code.require_file("Tarea.ex")
Code.require_file("Plan.ex")
Code.require_file("../Util2.ex", __DIR__)

defmodule Tareas do

  # LECTURA Y VALIDACION DE DATOS

  def leer_tareas(ruta) do
    if File.exists?(ruta) do
      {tareas, errores} =
        ruta
        |> Util2.lineas_utiles()
        |> Stream.map(fn {linea, _} -> parsear_linea(linea) end)
        |> Enum.reduce({[], []}, fn resultado, {tareas, errores} ->
          case resultado do
            {:ok, tarea} -> {[tarea | tareas], errores}
            {:error, error} -> {tareas, [error | errores]}
          end
        end)

      {:ok, Enum.reverse(tareas), Enum.reverse(errores)}
    else
      {:error, "No existe el archivo #{ruta}"}
    end
  end

  def parsear_linea(linea) do
    case String.split(linea, ";") do
      [id, duracion, plazo, deps] ->
        with {:ok, id} <- validar_id(String.trim(id)),
             {:ok, duracion} <- entero(duracion),
             :ok <- validar_duracion(duracion),
             {:ok, plazo} <- entero(plazo),
             :ok <- validar_plazo(plazo),
             {:ok, deps} <- parsear_deps(deps) do
          {:ok, Tarea.crear(id, duracion, plazo, deps)}
        end

      _ ->
        {:error, "La linea debe tener cuatro campos separados por ;"}
    end
  end

  defp validar_id(""), do: {:error, "El ID esta vacio"}

  defp validar_id(id) do
    if String.contains?(id, "|") do
      {:error, "El ID no puede contener |"}
    else
      {:ok, id}
    end
  end

  defp entero(texto) do
    case Integer.parse(String.trim(texto)) do
      {n, ""} -> {:ok, n}
      _ -> {:error, "Hay un valor que no es entero"}
    end
  end

  defp validar_duracion(n) do
    if n > 0, do: :ok, else: {:error, "La duracion debe ser mayor que cero"}
  end

  defp validar_plazo(n) do
    if n >= 0, do: :ok, else: {:error, "El plazo no puede ser negativo"}
  end

  defp parsear_deps(texto) do
    deps =
      if String.trim(texto) == "-" do
        []
      else
        texto |> String.split("|") |> Enum.map(&String.trim/1)
      end

    cond do
      "" in deps -> {:error, "Hay una dependencia vacia"}
      length(deps) != length(Enum.uniq(deps)) ->
        {:error, "Hay dependencias repetidas"}
      true -> {:ok, deps}
    end
  end

  # BUSQUEDA DE PLANES

  def planes(tareas), do: buscar(tareas, [], [], [], 0, 0)

  defp buscar([], _terminadas, orden, fines, _tiempo, penalizacion) do
    [Plan.crear(Enum.reverse(orden), Enum.reverse(fines), penalizacion)]
  end

  defp buscar(pendientes, terminadas, orden, fines, tiempo, penalizacion) do
    Stream.flat_map(habilitadas(pendientes, terminadas), fn tarea ->
      fin = tiempo + tarea.duracion
      atraso = max(0, fin - tarea.plazo)

      buscar(
        List.delete(pendientes, tarea),
        [tarea.id | terminadas],
        [tarea.id | orden],
        [{tarea.id, fin} | fines],
        fin,
        penalizacion + atraso
      )
    end)
  end

  defp habilitadas(pendientes, terminadas) do
    pendientes
    |> Util2.aplicar_filtro(fn t -> cumplidas?(t.dependencias, terminadas) end)
    |> Util2.ordenar(:asc, & &1.id)
  end

  defp cumplidas?([], _), do: true

  defp cumplidas?([dep | resto], terminadas) do
    if dep in terminadas, do: cumplidas?(resto, terminadas), else: false
  end

  # VALIDACIONES GENERALES

  defp validar_tareas(tareas) do
    ids = Enum.map(tareas, & &1.id)

    validar_ids(ids) ++
      validar_referencias(tareas, ids) ++
      validar_ciclos(tareas)
  end

  defp validar_ids(ids) do
    repetidos = ids -- Enum.uniq(ids)

    if repetidos == [] do
      []
    else
      ["Hay IDs repetidos: #{Enum.join(Enum.uniq(repetidos), ", ")}"]
    end
  end

  defp validar_referencias(tareas, ids) do
    Enum.flat_map(tareas, fn tarea ->
      Enum.flat_map(tarea.dependencias, fn dep ->
        cond do
          dep == tarea.id -> ["La tarea #{tarea.id} depende de si misma"]
          dep not in ids -> ["La dependencia #{dep} de #{tarea.id} no existe"]
          true -> []
        end
      end)
    end)
  end

  # DETECCION DE CICLOS

  defp validar_ciclos(tareas) do
    tareas
    |> buscar_ciclos_tareas(tareas, [])
    |> Enum.map(&normalizar_ciclo/1)
    |> Enum.uniq()
    |> Enum.map(fn ciclo ->
      "Hay un ciclo: #{Enum.join(ciclo ++ [hd(ciclo)], " -> ")}"
    end)
  end

  defp buscar_ciclos_tareas([], _tareas, ciclos), do: ciclos

  defp buscar_ciclos_tareas([tarea | resto], tareas, ciclos) do
    nuevos = buscar_ciclos(tarea.id, tareas, [])
    buscar_ciclos_tareas(resto, tareas, ciclos ++ nuevos)
  end

  defp buscar_ciclos(id, tareas, camino) do
    if id in camino do
      [extraer_ciclo(id, camino)]
    else
      case buscar_tarea(id, tareas) do
        nil -> []
        tarea ->
          buscar_en_deps(tarea.dependencias, tareas, camino ++ [id], [])
      end
    end
  end

  defp buscar_tarea(_id, []), do: nil

  defp buscar_tarea(id, [tarea | resto]) do
    if tarea.id == id, do: tarea, else: buscar_tarea(id, resto)
  end

  defp buscar_en_deps([], _tareas, _camino, ciclos), do: ciclos

  defp buscar_en_deps([dep | resto], tareas, camino, ciclos) do
    nuevos = buscar_ciclos(dep, tareas, camino)
    buscar_en_deps(resto, tareas, camino, ciclos ++ nuevos)
  end

  defp extraer_ciclo(id, [id | resto]), do: [id | resto]
  defp extraer_ciclo(id, [_ | resto]), do: extraer_ciclo(id, resto)

  defp normalizar_ciclo(ciclo) do
    menor = Enum.min(ciclo)
    pos = Enum.find_index(ciclo, &(&1 == menor))
    Enum.drop(ciclo, pos) ++ Enum.take(ciclo, pos)
  end

  # PROGRAMA PRINCIPAL

  def main do
    Util2.mostrar("=== PLANIFICACION DE TAREAS ===", :mensaje)

    case leer_tareas("tareas.csv") do
      {:error, error} ->
        Util2.mostrar(error, :error)

      {:ok, [], []} ->
        Util2.mostrar("El proyecto esta vacio", :mensaje)

      {:ok, tareas, errores} ->
        errores_validacion =
          validar_tareas(tareas)

        if errores != [] or errores_validacion != [] do
          Util2.mostrar("Hay errores. No se buscaran planes.", :error)
          Enum.each(errores, &Util2.mostrar(&1, :error))
          Enum.each(errores_validacion, &Util2.mostrar(&1, :error))
        else
          Util2.mostrar("Validacion correcta", :mensaje)
          mostrar_planes(tareas)
        end
    end
  end

  # GUARDAR RESULTADOS

  defp mostrar_planes(tareas) do
    duracion_total = Enum.sum(Enum.map(tareas, & &1.duracion))
    archivo = File.open!("planes.csv", [:write])
    IO.write(archivo, "id;orden;duracion_total;penalizacion\n")

    resultado =
      Enum.reduce(planes(tareas), {0, nil, []}, fn plan, {total, minima, mejores} ->
        numero = total + 1
        orden = Enum.join(plan.orden, "!")

        IO.write(archivo, "#{numero};#{orden};#{duracion_total};#{plan.penalizacion}\n")

        cond do
          minima == nil ->
            {numero, plan.penalizacion, [plan]}

          plan.penalizacion < minima ->
            {numero, plan.penalizacion, [plan]}

          plan.penalizacion == minima ->
            {numero, minima, mejores ++ [plan]}

          true ->
            {numero, minima, mejores}
        end
      end)

    File.close(archivo)

    {total, minima, mejores} = resultado

    escribir_resumen(total, minima, mejores, duracion_total)
    escribir_mejor_svg(tareas, mejores, duracion_total)

    Util2.mostrar("Total de planes: #{total}", :mensaje)
    Util2.mostrar("Tiempo total: #{duracion_total}", :mensaje)
    Util2.mostrar("Penalizacion minima: #{minima}", :mensaje)
    Util2.mostrar("Archivos creados correctamente", :mensaje)
  end

  defp escribir_resumen(total, minima, mejores, duracion_total) do
    texto =
      if total == 0 do
        "Resumen\nNo existen planes validos.\n"
      else
        lista =
          Enum.map(mejores, fn plan ->
            "#{Enum.join(plan.orden, " - ")} (penalizacion #{plan.penalizacion})"
          end)

        """
        Resumen

        Total de planes: #{total}
        Tiempo total del proyecto: #{duracion_total}
        Penalizacion minima: #{minima}

        Planes con penalizacion minima:
        #{Enum.join(lista, "\n")}
        """
      end

    File.write!("resumen_tareas.txt", texto)
  end

  # DIAGRAMA SVG

  defp escribir_mejor_svg(_tareas, [], _duracion_total) do
    File.write!("mejor_plan.svg", """
    <svg xmlns="http://www.w3.org/2000/svg" width="400" height="120">
      <text x="10" y="25" font-size="18">No hay planes disponibles</text>
    </svg>
    """)
  end

  defp escribir_mejor_svg(tareas, mejores, duracion_total) do
    mejor = hd(mejores)
    archivo = File.open!("mejor_plan.svg", [:write])

    escala = 50
    margen = 140
    ancho = margen + duracion_total * escala + 50
    alto = 100 + length(mejor.orden) * 45

    IO.write(archivo, """
    <svg xmlns="http://www.w3.org/2000/svg"
         width="#{ancho}" height="#{alto}"
         viewBox="0 0 #{ancho} #{alto}">
    <rect width="100%" height="100%" fill="white"/>
    <text x="20" y="30" font-size="20">Diagrama de Gantt - Mejor plan</text>
    <line x1="#{margen}" y1="55" x2="#{ancho - 20}" y2="55" stroke="black"/>
    """)

    Enum.each(0..duracion_total, fn tiempo ->
      x = margen + tiempo * escala

      IO.write(archivo, """
      <line x1="#{x}" y1="50" x2="#{x}" y2="60" stroke="black"/>
      <text x="#{x}" y="45" font-size="12" text-anchor="middle">#{tiempo}</text>
      """)
    end)

    Enum.each(Enum.with_index(mejor.orden), fn {id, indice} ->
      tarea = Enum.find(tareas, &(&1.id == id))
      {_, fin} = List.keyfind(mejor.finalizaciones, id, 0)

      inicio = fin - tarea.duracion
      x = margen + inicio * escala
      y = 75 + indice * 45
      ancho_barra = tarea.duracion * escala
      color = if fin > tarea.plazo, do: "red", else: "green"

      IO.write(archivo, """
      <text x="10" y="#{y + 18}" font-size="14">#{escapar_xml(id)}</text>
      <rect x="#{x}" y="#{y}" width="#{ancho_barra}" height="25"
            fill="#{color}" stroke="black"/>
      <text x="#{x + ancho_barra / 2}" y="#{y + 17}"
            font-size="12" text-anchor="middle" fill="white">
        #{inicio} - #{fin}
      </text>
      """)
    end)

    IO.write(archivo, """
    <text x="20" y="#{alto - 10}" font-size="12">
      Verde: cumple el plazo | Rojo: se pasa del plazo
    </text>
    </svg>
    """)

    File.close(archivo)
  end

  defp escapar_xml(texto) do
    texto
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end
end

Tareas.main()