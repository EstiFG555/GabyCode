/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Class.java to edit this template
 */

/**
 *
 * @author facu
 */
package gabycodecompiler.generador;

import com.google.gson.Gson;
import gabycodecompiler.modelo.EntradaDato;
import gabycodecompiler.modelo.Grafo;
import gabycodecompiler.modelo.Nodo;
import java.io.File;
import java.io.FileReader;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

public class GeneradorBytecode {

    private static final Map<String, List<String>> ORDEN_PARAMETROS_HOST = new HashMap<>();

    static {
        ORDEN_PARAMETROS_HOST.put("APPLY_DISCOUNT", Arrays.asList("producto", "porcentaje"));
        ORDEN_PARAMETROS_HOST.put("SHOW_ALERT", Arrays.asList("mensaje"));
        ORDEN_PARAMETROS_HOST.put("GET_STOCK", Arrays.asList("producto"));
        ORDEN_PARAMETROS_HOST.put("GET_PRODUCT_BY_ID", Arrays.asList("id_producto"));
        ORDEN_PARAMETROS_HOST.put("CALCULATE_SALE_TOTAL", Arrays.asList("lista_productos"));
        ORDEN_PARAMETROS_HOST.put("REGISTER_SALE", Arrays.asList("lista_productos", "total"));
        ORDEN_PARAMETROS_HOST.put("SHOW_TOTAL", Arrays.asList("total"));
    }

    private static class DatosSubrutina {
        Grafo grafo;
        List<String> ordenEntradas = new ArrayList<>();
    }

    public static List<Instruccion> generar(List<Nodo> nodos) {
        Grafo g = new Grafo();
        g.setNodos(nodos);
        return generar(g);
    }

    public static List<Instruccion> generar(Grafo grafo) {
        cargarOrdenDesdeCatalogoJson();

        List<Instruccion> instrucciones = new ArrayList<>();
        if (grafo == null || grafo.getNodos() == null || grafo.getNodos().isEmpty()) {
            return instrucciones;
        }

        List<Instruccion> llamadasSubrutinasPendientes = new ArrayList<>();
        List<String> nombresSubrutinasLlamadas = new ArrayList<>();

        compilarGrafoEnLista(grafo, new ArrayList<>(), instrucciones, false, llamadasSubrutinasPendientes, nombresSubrutinasLlamadas);

        // Instrucción de cierre del programa principal
        instrucciones.add(new Instruccion(CodigoOperacion.HALT));

        // Enlazar y compilar las Subrutinas invocadas al final del archivo bytecode
        Map<String, Integer> direccionesSubrutinas = new LinkedHashMap<>();
        for (int i = 0; i < nombresSubrutinasLlamadas.size(); i++) {
            String opSub = nombresSubrutinasLlamadas.get(i);
            Instruccion instCall = llamadasSubrutinasPendientes.get(i);

            if (!direccionesSubrutinas.containsKey(opSub)) {
                DatosSubrutina datosSub = cargarDatosSubrutina(opSub);
                if (datosSub != null && datosSub.grafo != null) {
                    int dirInicio = instrucciones.size();
                    direccionesSubrutinas.put(opSub, dirInicio);
                    compilarGrafoEnLista(datosSub.grafo, datosSub.ordenEntradas, instrucciones, true,
                            llamadasSubrutinasPendientes, nombresSubrutinasLlamadas);
                    // Retorno por defecto (0) si el flujo de la subrutina llega al final sin ejecutar RETURN_VAL
                    instrucciones.add(new Instruccion(CodigoOperacion.PUSH, 0));
                    instrucciones.add(new Instruccion(CodigoOperacion.RET));
                } else {
                    direccionesSubrutinas.put(opSub, instrucciones.size() - 1);
                }
            }
            instCall.setOperando(direccionesSubrutinas.get(opSub));
        }

        return instrucciones;
    }

    private static void compilarGrafoEnLista(
            Grafo grafo,
            List<String> parametrosEntradaSubrutina,
            List<Instruccion> instrucciones,
            boolean esSubrutina,
            List<Instruccion> llamadasSubrutinasPendientes,
            List<String> nombresSubrutinasLlamadas) {

        Map<Integer, Nodo> mapaNodos = new HashMap<>();
        Set<Integer> nodosReferenciados = new HashSet<>();

        for (Nodo n : grafo.getNodos()) {
            mapaNodos.put(n.getId(), n);
            if (n.getDatosEntrada() != null) {
                for (EntradaDato ed : n.getDatosEntrada().values()) {
                    if (ed != null && "REFERENCIA_NODO".equalsIgnoreCase(ed.getFuente()) && ed.getIdOrigen() != null) {
                        nodosReferenciados.add(ed.getIdOrigen());
                    }
                }
            }
        }

        // 1. Si es Subrutina, desapilar primero sus parámetros formales de entrada en orden inverso (LIFO)
        if (esSubrutina && parametrosEntradaSubrutina != null) {
            for (int i = parametrosEntradaSubrutina.size() - 1; i >= 0; i--) {
                String nombreParam = parametrosEntradaSubrutina.get(i);
                instrucciones.add(new Instruccion(CodigoOperacion.STORE, nombreParam));
            }
        }

        // 2. Inicializar las variables_locales propias del ámbito actual (Principal o Subrutina)
        if (grafo.getVariablesLocales() != null) {
            for (Map<String, Object> varLocal : grafo.getVariablesLocales()) {
                String nombre = String.valueOf(varLocal.get("nombre"));
                Object valorInicial = varLocal.get("valor_inicial");
                if (valorInicial == null) valorInicial = 0;
                instrucciones.add(new Instruccion(CodigoOperacion.PUSH, formatearLiteral(valorInicial)));
                instrucciones.add(new Instruccion(CodigoOperacion.STORE, nombre));
            }
        }

        Nodo nodoEvento = null;
        for (Nodo n : grafo.getNodos()) {
            if ("EVENTO".equalsIgnoreCase(n.getTipo())) {
                nodoEvento = n;
                break;
            }
        }
        if (nodoEvento == null && !grafo.getNodos().isEmpty()) {
            nodoEvento = grafo.getNodos().get(0);
        }

        if (nodoEvento != null) {
            compilarSecuencia(nodoEvento.getId(), mapaNodos, nodosReferenciados, instrucciones,
                    llamadasSubrutinasPendientes, nombresSubrutinasLlamadas);
        }
    }

    private static void compilarSecuencia(
            int idActual,
            Map<Integer, Nodo> mapaNodos,
            Set<Integer> nodosReferenciados,
            List<Instruccion> instrucciones,
            List<Instruccion> llamadasSubrutinasPendientes,
            List<String> nombresSubrutinasLlamadas) {

        while (idActual > 0) {
            Nodo nodo = mapaNodos.get(idActual);
            if (nodo == null) break;

            String tipo = nodo.getTipo() != null ? nodo.getTipo().toUpperCase() : "";
            String operacion = nodo.getOperacion() != null ? nodo.getOperacion().toUpperCase() : "";

            switch (tipo) {
                case "EVENTO":
                    idActual = obtenerSalida(nodo, 0);
                    break;

                case "CONTROL":
                    compilarNodoControl(nodo, operacion, mapaNodos, nodosReferenciados, instrucciones,
                            llamadasSubrutinasPendientes, nombresSubrutinasLlamadas);
                    idActual = obtenerSalida(nodo, 2);
                    break;

                case "ACCION":
                case "ACCIÓN":
                default:
                    compilarNodoAccion(nodo, operacion, mapaNodos, nodosReferenciados, instrucciones,
                            llamadasSubrutinasPendientes, nombresSubrutinasLlamadas);
                    idActual = obtenerSalida(nodo, 0);
                    break;
            }
        }
    }

    private static void compilarNodoControl(
            Nodo nodo,
            String operacion,
            Map<Integer, Nodo> mapaNodos,
            Set<Integer> nodosReferenciados,
            List<Instruccion> instrucciones,
            List<Instruccion> llamadasSubrutinasPendientes,
            List<String> nombresSubrutinasLlamadas) {

        int idRamaVerdadera = obtenerSalida(nodo, 0);
        int idRamaFalsa = obtenerSalida(nodo, 1);

        if ("IF_ELSE".equals(operacion)) {
            EntradaDato cond = obtenerEntrada(nodo, "condicion");
            evaluarEntradaDato(cond, mapaNodos, instrucciones);

            Instruccion jmpIfFalse = new Instruccion(CodigoOperacion.JMP_IF_FALSE, 0);
            instrucciones.add(jmpIfFalse);

            if (idRamaVerdadera > 0) {
                compilarSecuencia(idRamaVerdadera, mapaNodos, nodosReferenciados, instrucciones,
                        llamadasSubrutinasPendientes, nombresSubrutinasLlamadas);
            }

            if (idRamaFalsa > 0) {
                Instruccion jmpFinIf = new Instruccion(CodigoOperacion.JMP, 0);
                instrucciones.add(jmpFinIf);

                jmpIfFalse.setOperando(instrucciones.size());

                compilarSecuencia(idRamaFalsa, mapaNodos, nodosReferenciados, instrucciones,
                        llamadasSubrutinasPendientes, nombresSubrutinasLlamadas);

                jmpFinIf.setOperando(instrucciones.size());
            } else {
                jmpIfFalse.setOperando(instrucciones.size());
            }

        } else if ("WHILE".equals(operacion)) {
            int indiceInicioBucle = instrucciones.size();

            EntradaDato cond = obtenerEntrada(nodo, "condicion");
            evaluarEntradaDato(cond, mapaNodos, instrucciones);

            Instruccion jmpSalida = new Instruccion(CodigoOperacion.JMP_IF_FALSE, 0);
            instrucciones.add(jmpSalida);

            if (idRamaVerdadera > 0) {
                compilarSecuencia(idRamaVerdadera, mapaNodos, nodosReferenciados, instrucciones,
                        llamadasSubrutinasPendientes, nombresSubrutinasLlamadas);
            }

            instrucciones.add(new Instruccion(CodigoOperacion.JMP, indiceInicioBucle));
            jmpSalida.setOperando(instrucciones.size());

        } else if ("FOREACH".equals(operacion)) {
            String varIndice = "__idx_" + nodo.getId();
            String varSalidaElemento = "__salida_nodo_" + nodo.getId();

            instrucciones.add(new Instruccion(CodigoOperacion.PUSH, 0));
            instrucciones.add(new Instruccion(CodigoOperacion.STORE, varIndice));

            int indiceInicioFor = instrucciones.size();
            instrucciones.add(new Instruccion(CodigoOperacion.LOAD, varIndice));
            EntradaDato coleccion = obtenerEntrada(nodo, "coleccion");
            evaluarEntradaDato(coleccion, mapaNodos, instrucciones);
            instrucciones.add(new Instruccion(CodigoOperacion.CALL_HOST, "HAS_NEXT 2"));

            Instruccion jmpSalida = new Instruccion(CodigoOperacion.JMP_IF_FALSE, 0);
            instrucciones.add(jmpSalida);

            instrucciones.add(new Instruccion(CodigoOperacion.LOAD, varIndice));
            evaluarEntradaDato(coleccion, mapaNodos, instrucciones);
            instrucciones.add(new Instruccion(CodigoOperacion.CALL_HOST, "GET_ITEM 2"));
            instrucciones.add(new Instruccion(CodigoOperacion.STORE, varSalidaElemento));

            EntradaDato varIter = obtenerEntrada(nodo, "variable_iteradora");
            if (varIter != null && varIter.getNombre() != null && !varIter.getNombre().isEmpty()) {
                instrucciones.add(new Instruccion(CodigoOperacion.LOAD, varSalidaElemento));
                instrucciones.add(new Instruccion(CodigoOperacion.STORE, varIter.getNombre()));
            }

            if (idRamaVerdadera > 0) {
                compilarSecuencia(idRamaVerdadera, mapaNodos, nodosReferenciados, instrucciones,
                        llamadasSubrutinasPendientes, nombresSubrutinasLlamadas);
            }

            instrucciones.add(new Instruccion(CodigoOperacion.LOAD, varIndice));
            instrucciones.add(new Instruccion(CodigoOperacion.PUSH, 1));
            instrucciones.add(new Instruccion(CodigoOperacion.ADD));
            instrucciones.add(new Instruccion(CodigoOperacion.STORE, varIndice));
            instrucciones.add(new Instruccion(CodigoOperacion.JMP, indiceInicioFor));

            jmpSalida.setOperando(instrucciones.size());
        }
    }

    private static void compilarNodoAccion(
            Nodo nodo,
            String operacion,
            Map<Integer, Nodo> mapaNodos,
            Set<Integer> nodosReferenciados,
            List<Instruccion> instrucciones,
            List<Instruccion> llamadasSubrutinasPendientes,
            List<String> nombresSubrutinasLlamadas) {

        // 1. Asignación de variable local (SET_VAR)
        if ("SET_VAR".equals(operacion)) {
            EntradaDato entradaValor = obtenerEntrada(nodo, "valor");
            EntradaDato entradaDestino = obtenerEntrada(nodo, "variable_destino");
            if (entradaDestino != null && entradaDestino.getNombre() != null) {
                evaluarEntradaDato(entradaValor, mapaNodos, instrucciones);
                instrucciones.add(new Instruccion(CodigoOperacion.STORE, entradaDestino.getNombre()));
            }
            return;
        }

        // 2. Retorno explícito de valor desde una Subrutina (RETURN_VAL)
        if ("RETURN_VAL".equals(operacion)) {
            EntradaDato entradaRetorno = obtenerEntrada(nodo, "valor_retorno");
            evaluarEntradaDato(entradaRetorno, mapaNodos, instrucciones);
            instrucciones.add(new Instruccion(CodigoOperacion.RET));
            return;
        }

        // 3. Llamada a Subrutina (Acción Compuesta con prefijo SUB_)
        if (operacion.startsWith("SUB_")) {
            DatosSubrutina infoSub = cargarDatosSubrutina(operacion);
            if (infoSub != null && !infoSub.ordenEntradas.isEmpty()) {
                for (String paramName : infoSub.ordenEntradas) {
                    evaluarEntradaDato(obtenerEntrada(nodo, paramName), mapaNodos, instrucciones);
                }
            } else {
                apilarArgumentosAccion(nodo, operacion, mapaNodos, instrucciones);
            }
            Instruccion instCall = new Instruccion(CodigoOperacion.CALL, 0);
            instrucciones.add(instCall);
            llamadasSubrutinasPendientes.add(instCall);
            nombresSubrutinasLlamadas.add(operacion);

            // Al retornar la subrutina, si alguien consume su "resultado", lo guardamos en __salida_nodo_<id>
            if (nodosReferenciados.contains(nodo.getId())) {
                instrucciones.add(new Instruccion(CodigoOperacion.STORE, "__salida_nodo_" + nodo.getId()));
            } else {
                instrucciones.add(new Instruccion(CodigoOperacion.POP));
            }
            return;
        }

        // 4. Llamada estándar al Host (CALL_HOST)
        int aridad = apilarArgumentosAccion(nodo, operacion, mapaNodos, instrucciones);
        instrucciones.add(new Instruccion(CodigoOperacion.CALL_HOST, operacion + " " + aridad));

        if (nodosReferenciados.contains(nodo.getId())) {
            instrucciones.add(new Instruccion(CodigoOperacion.STORE, "__salida_nodo_" + nodo.getId()));
        } else {
            instrucciones.add(new Instruccion(CodigoOperacion.POP));
        }
    }

    private static int apilarArgumentosAccion(
            Nodo nodo,
            String operacion,
            Map<Integer, Nodo> mapaNodos,
            List<Instruccion> instrucciones) {

        if (nodo.getDatosEntrada() == null || nodo.getDatosEntrada().isEmpty()) {
            return 0;
        }

        if (ORDEN_PARAMETROS_HOST.containsKey(operacion)) {
            List<String> orden = ORDEN_PARAMETROS_HOST.get(operacion);
            for (String nombreParam : orden) {
                evaluarEntradaDato(obtenerEntrada(nodo, nombreParam), mapaNodos, instrucciones);
            }
            return orden.size();
        }

        int count = 0;
        for (Map.Entry<String, EntradaDato> entry : nodo.getDatosEntrada().entrySet()) {
            if (entry.getValue() != null) {
                evaluarEntradaDato(entry.getValue(), mapaNodos, instrucciones);
                count++;
            }
        }
        return count;
    }

    private static void compilarNodoExpresion(
            Nodo nodoExpr,
            Map<Integer, Nodo> mapaNodos,
            List<Instruccion> instrucciones) {

        String op = nodoExpr.getOperacion() != null ? nodoExpr.getOperacion().toUpperCase() : "";

        if ("GET_STOCK".equals(op)) {
            evaluarEntradaDato(obtenerEntrada(nodoExpr, "producto"), mapaNodos, instrucciones);
            instrucciones.add(new Instruccion(CodigoOperacion.CALL_HOST, "GET_STOCK 1"));
            return;
        }

        evaluarEntradaDato(obtenerEntrada(nodoExpr, "valor_a"), mapaNodos, instrucciones);
        evaluarEntradaDato(obtenerEntrada(nodoExpr, "valor_b"), mapaNodos, instrucciones);

        switch (op) {
            case "LESS_THAN", "OP_CMP_LT" -> instrucciones.add(new Instruccion(CodigoOperacion.LT));
            case "GREATER_THAN", "OP_CMP_GT" -> instrucciones.add(new Instruccion(CodigoOperacion.GT));
            case "EQUAL", "OP_CMP_EQ" -> instrucciones.add(new Instruccion(CodigoOperacion.EQ));
            case "ADD", "OP_ADD" -> instrucciones.add(new Instruccion(CodigoOperacion.ADD));
            case "SUB", "OP_SUB" -> instrucciones.add(new Instruccion(CodigoOperacion.SUB));
            case "MUL", "OP_MUL" -> instrucciones.add(new Instruccion(CodigoOperacion.MUL));
            case "DIV", "OP_DIV" -> instrucciones.add(new Instruccion(CodigoOperacion.DIV));
            case "AND", "OP_AND" -> instrucciones.add(new Instruccion(CodigoOperacion.AND));
            case "OR", "OP_OR" -> instrucciones.add(new Instruccion(CodigoOperacion.OR));
            default -> throw new IllegalArgumentException("Operación de expresión desconocida: " + op);
        }
    }

    private static void evaluarEntradaDato(
            EntradaDato entrada,
            Map<Integer, Nodo> mapaNodos,
            List<Instruccion> instrucciones) {

        if (entrada == null || entrada.getFuente() == null) {
            instrucciones.add(new Instruccion(CodigoOperacion.PUSH, 0));
            return;
        }

        String fuente = entrada.getFuente().toUpperCase();
        switch (fuente) {
            case "LITERAL" -> instrucciones.add(new Instruccion(CodigoOperacion.PUSH, formatearLiteral(entrada.getValor())));
            case "VARIABLE" -> instrucciones.add(new Instruccion(CodigoOperacion.LOAD, entrada.getNombre()));
            case "REFERENCIA_NODO" -> {
                if (entrada.getIdOrigen() != null) {
                    Nodo nodoOrigen = mapaNodos.get(entrada.getIdOrigen());
                    if (nodoOrigen != null) {
                        if ("EXPRESION".equalsIgnoreCase(nodoOrigen.getTipo())) {
                            compilarNodoExpresion(nodoOrigen, mapaNodos, instrucciones);
                        } else if ("EVENTO".equalsIgnoreCase(nodoOrigen.getTipo())) {
                            String puerto = entrada.getPuerto();
                            if (puerto == null || puerto.isBlank() || "producto_leido".equals(puerto)) {
                                instrucciones.add(new Instruccion(CodigoOperacion.LOAD, "ProductoActual"));
                            } else {
                                instrucciones.add(new Instruccion(CodigoOperacion.LOAD, puerto));
                            }
                        } else {
                            instrucciones.add(new Instruccion(CodigoOperacion.LOAD, "__salida_nodo_" + nodoOrigen.getId()));
                        }
                    }
                }
            }
        }
    }

    @SuppressWarnings("unchecked")
    private static void cargarOrdenDesdeCatalogoJson() {
        String[] rutas = {
            "../../compilador-gráfico/catalogo_host.json",
            "../compilador-gráfico/catalogo_host.json",
            "catalogo_host.json"
        };
        for (String r : rutas) {
            File f = new File(r);
            if (f.exists()) {
                try (FileReader reader = new FileReader(f)) {
                    Map<String, Object> data = new Gson().fromJson(reader, Map.class);
                    if (data != null && data.get("acciones") instanceof List<?> acciones) {
                        for (Object obj : acciones) {
                            if (obj instanceof Map<?, ?> acc) {
                                String op = String.valueOf(acc.get("operacion")).toUpperCase();
                                if (acc.get("orden_entradas") instanceof List<?> ordenRaw) {
                                    List<String> orden = new ArrayList<>();
                                    for (Object item : ordenRaw) orden.add(String.valueOf(item));
                                    ORDEN_PARAMETROS_HOST.put(op, orden);
                                }
                            }
                        }
                    }
                    return;
                } catch (Exception ignored) {
                }
            }
        }
    }

    @SuppressWarnings("unchecked")
    private static DatosSubrutina cargarDatosSubrutina(String opSub) {
        String nombreArchivo = opSub.toLowerCase() + ".json";
        String[] rutas = {
            "../../compilador-gráfico/subrutinas/" + nombreArchivo,
            "../compilador-gráfico/subrutinas/" + nombreArchivo,
            "subrutinas/" + nombreArchivo
        };
        Gson gson = new Gson();
        for (String r : rutas) {
            File f = new File(r);
            if (f.exists()) {
                try (FileReader reader = new FileReader(f)) {
                    Map<String, Object> wrapper = gson.fromJson(reader, Map.class);
                    if (wrapper != null && wrapper.containsKey("grafo")) {
                        DatosSubrutina ds = new DatosSubrutina();
                        if (wrapper.get("orden_entradas") instanceof List<?> listaOrden) {
                            for (Object o : listaOrden) ds.ordenEntradas.add(String.valueOf(o));
                        }
                        String grafoJson = gson.toJson(wrapper.get("grafo"));
                        ds.grafo = gson.fromJson(grafoJson, Grafo.class);
                        ORDEN_PARAMETROS_HOST.put(opSub.toUpperCase(), ds.ordenEntradas);
                        return ds;
                    }
                } catch (Exception ignored) {
                }
            }
        }
        return null;
    }

    private static EntradaDato obtenerEntrada(Nodo nodo, String clave) {
        if (nodo.getDatosEntrada() == null) return null;
        return nodo.getDatosEntrada().get(clave);
    }

    private static int obtenerSalida(Nodo nodo, int indice) {
        if (nodo.getSalidasEjecucion() == null || indice >= nodo.getSalidasEjecucion().size()) {
            return 0;
        }
        Integer id = nodo.getSalidasEjecucion().get(indice);
        return id != null ? id : 0;
    }

    private static Object formatearLiteral(Object valor) {
        if (valor instanceof Double d) {
            if (d == Math.floor(d) && !Double.isInfinite(d)) {
                return d.intValue();
            }
        }
        return valor;
    }
}