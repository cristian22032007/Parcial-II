Code.require_file("../Util2.ex", __DIR__)

defmodule Parentesis do

  def generar(n, p), do: gen("", n, 0, 0, p)

  defp gen(acc, n, n, n, _p), do: [acc]

  defp gen(acc, n, ab, ce, p) do
    Stream.flat_map([:abrir, :cerrar], fn
      :abrir when ab < n and ab - ce < p -> gen(acc <> "(", n, ab + 1, ce, p)
      :cerrar when ce < ab -> gen(acc <> ")", n, ab, ce + 1, p)
      _ -> []
    end)
  end

  # parametros.csv -> un archivo por cada par (n, p)
  def procesar_parametros(ruta) do
    if File.exists?(ruta) do
      ruta
      |> Util2.lineas_utiles()
      |> Enum.each(fn {linea, i} ->
        case parsear_parametros(linea) do
          {:ok, n, p} ->
            total = escribir_soluciones(n, p)
            Util2.mostrar("n=#{n}, p=#{p} -> total: #{total}", :mensaje)

          {:error, motivo} ->
            Util2.mostrar("AVISO: #{ruta}, linea #{i}: #{motivo} (#{inspect(linea)})", :error)
        end
      end)
    else
      Util2.mostrar("AVISO: no existe el archivo #{ruta}", :error)
    end
  end

  defp parsear_parametros(linea) do
    with [sn, sp] <- String.split(linea, ";"),
         {n, ""} <- Integer.parse(String.trim(sn)),
         {p, ""} <- Integer.parse(String.trim(sp)) do
      cond do
        n < 1 -> {:error, "n debe ser >= 1"}
        p < 1 or p > n -> {:error, "p debe cumplir 1 <= p <= n"}
        true -> {:ok, n, p}
      end
    else
      _ -> {:error, "formato invalido, se esperaba n;p con enteros"}
    end
  end

  # Escribe cada solucion al consumirla y cuenta el total
  defp escribir_soluciones(n, p) do
    archivo = "parentesis_n#{n}_p#{p}.txt"
    {:ok, f} = File.open(archivo, [:write])

    total =
      Enum.reduce(generar(n, p), 0, fn sol, cont ->
        IO.puts(f, sol)
        cont + 1
      end)

    IO.puts(f, "Total: #{total}")
    File.close(f)
    total
  end

  # primera_n18_p18.txt -> solo el primer elemento del Stream
  def primera_n18 do
    [primera] = generar(18, 18) |> Enum.take(1)
    File.write!("primera_n18_p18.txt", primera <> "\n")
    Util2.mostrar("primera_n18_p18.txt -> #{primera}", :mensaje)
  end

  # stream infinito: n = 1, 2, 3, ... con p = n
  # Se detiene despues del primer total >= 1000
  def secuencia_infinita do
    {:ok, f} = File.open("secuencia_parentesis.csv", [:write])
    IO.puts(f, "n;total")

    Stream.iterate(1, &(&1 + 1))
    |> Stream.map(fn n -> {n, Enum.count(generar(n, n))} end)
    |> Stream.transform(false, fn
      _par, true -> {:halt, true}
      {_n, total} = par, false -> {[par], total >= 1000}
    end)
    |> Enum.each(fn {n, total} ->
      IO.puts(f, "#{n};#{total}")
      Util2.mostrar("secuencia: n=#{n}, total=#{total}", :mensaje)
    end)

    File.close(f)
  end

  # Validacion recursiva

  # Regla: longitud. Cuenta cuantas letras hay.
  def largo([], acc), do: acc
  def largo([_ | resto], acc), do: largo(resto, acc + 1)

  # Regla: solo ( y ). Devuelve {posicion, letra} de la primera letra
  # rara, o nil si no hay ninguna.
  def primer_invalido([], _pos), do: nil

  def primer_invalido([c | resto], pos) when c == "(" or c == ")",
    do: primer_invalido(resto, pos + 1)

  def primer_invalido([c | _resto], pos), do: {pos, c}

  # Regla: nunca cerrar mas de lo abierto. Devuelve el primer prefijo
  # donde se cierra de mas, o nil si nunca pasa.
  # bal = abiertos - cerrados, pref = lo que llevo leido
  def cierre_de_mas([], _bal, _pref), do: nil

  def cierre_de_mas(["(" | resto], bal, pref),
    do: cierre_de_mas(resto, bal + 1, pref <> "(")

  def cierre_de_mas([")" | resto], bal, pref) do
    if bal - 1 < 0 do
      pref <> ")"
    else
      cierre_de_mas(resto, bal - 1, pref <> ")")
    end
  end

  def cierre_de_mas([otra | resto], bal, pref),
    do: cierre_de_mas(resto, bal, pref <> otra)

  # Regla: balance final. Devuelve abiertos - cerrados al terminar.
  def balance([], bal), do: bal
  def balance(["(" | resto], bal), do: balance(resto, bal + 1)
  def balance([")" | resto], bal), do: balance(resto, bal - 1)
  def balance([_otra | resto], bal), do: balance(resto, bal)

  # Regla: profundidad. Devuelve el mayor balance que se alcanzo.
  def maxima([], _bal, mayor), do: mayor
  def maxima(["(" | resto], bal, mayor), do: maxima(resto, bal + 1, max(mayor, bal + 1))
  def maxima([")" | resto], bal, mayor), do: maxima(resto, bal - 1, mayor)
  def maxima([_otra | resto], bal, mayor), do: maxima(resto, bal, mayor)

  # Primer prefijo que supera la profundidad p, o nil si nunca la supera.
  def exceso([], _bal, _p, _pref), do: nil

  def exceso(["(" | resto], bal, p, pref) do
    if bal + 1 > p do
      pref <> "("
    else
      exceso(resto, bal + 1, p, pref <> "(")
    end
  end

  def exceso([")" | resto], bal, p, pref), do: exceso(resto, bal - 1, p, pref <> ")")
  def exceso([otra | resto], bal, p, pref), do: exceso(resto, bal, p, pref <> otra)

  # Junta todas las reglas. Devuelve la lista de motivos
  def motivos(n, p, cadena) do
    letras = String.graphemes(cadena)

    largo = largo(letras, 0)
    invalido = primer_invalido(letras, 1)
    cierre = cierre_de_mas(letras, 0, "")
    bal_final = balance(letras, 0)
    max_prof = maxima(letras, 0, 0)

    m1 = if largo != 2 * n, do: ["longitud #{largo}, se esperaba #{2 * n}"], else: []

    m2 =
      if invalido != nil,
        do: ["caracter invalido #{inspect(elem(invalido, 1))} en la posicion #{elem(invalido, 0)}"],
        else: []

    m3 =
      if cierre != nil,
        do: ["cierra mas de lo abierto, primer prefijo problematico: #{cierre}"],
        else: []

    m4 =
      if bal_final != 0,
        do: ["termina con balance #{bal_final} (debe ser 0)"],
        else: []

    m5 =
      if max_prof > p do
        prefijo = exceso(letras, 0, p, "")
        ["profundidad alcanzada #{max_prof} > #{p}, primer prefijo que la excede: #{prefijo}"]
      else
        []
      end

    m1 ++ m2 ++ m3 ++ m4 ++ m5
  end

  # propuestas.txt - verificacion_parentesis.txt
  def verificar_propuestas(ruta) do
    if File.exists?(ruta) do
      {:ok, f} = File.open("verificacion_parentesis.txt", [:write])

      ruta
      |> Util2.lineas_utiles()
      |> Enum.each(fn {linea, i} ->
        resultado =
          with [sn, sp, cadena] <- String.split(linea, ";", parts: 3),
               {n, ""} <- Integer.parse(String.trim(sn)),
               {p, ""} <- Integer.parse(String.trim(sp)) do
            {:ok, n, p, String.trim(cadena)}
          else
            _ -> :error
          end

        texto =
          case resultado do
            :error ->
              "Linea #{i}: registro incorrecto, se esperaba n;p;cadena -> #{linea}"

            {:ok, n, p, cadena} ->
              case motivos(n, p, cadena) do
                [] ->
                  "Linea #{i}: n=#{n} p=#{p} #{cadena} -> VALIDA"

                lista ->
                  "Linea #{i}: n=#{n} p=#{p} #{cadena} -> INVALIDA\n" <>
                    (lista
                     |> Util2.convertir_coleccion_mensaje(fn m -> "    - #{m}\n" end)
                     |> IO.iodata_to_binary()
                     |> String.trim_trailing())
              end
          end

        IO.puts(f, texto)
        Util2.mostrar(texto, :mensaje)
      end)

      File.close(f)
    else
      Util2.mostrar("AVISO: no existe el archivo #{ruta}", :error)
    end
  end


  def main do
    Util2.mostrar(" 1. parametros.csv ", :mensaje)
    procesar_parametros("parametros.csv")

    Util2.mostrar("\n 2. primera n=18, p=18 ", :mensaje)
    primera_n18()

    Util2.mostrar("\n 3. Stream infinito ", :mensaje)
    secuencia_infinita()

    Util2.mostrar("\n 4. Verificacion de propuestas ", :mensaje)
    verificar_propuestas("propuestas.txt")
  end
end

Parentesis.main()
