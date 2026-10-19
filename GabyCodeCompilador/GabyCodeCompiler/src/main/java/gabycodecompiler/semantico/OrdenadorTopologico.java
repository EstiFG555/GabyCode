/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Class.java to edit this template
 */
package gabycodecompiler.semantico;

/**
 *
 * @author facu
 */
import gabycodecompiler.modelo.EntradaDato;
import gabycodecompiler.modelo.Grafo;
import gabycodecompiler.modelo.Nodo;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

public class OrdenadorTopologico {

    public static List<Nodo> ordenar(Grafo grafo) {
        if (grafo == null || grafo.getNodos() == null || grafo.getNodos().isEmpty()) {
            return Collections.emptyList();
        }

        Map<Integer, Nodo> mapaNodos = new HashMap<>();
        for (Nodo n : grafo.getNodos()) {
            mapaNodos.put(n.getId(), n);
        }

        List<Nodo> ordenados = new ArrayList<>();
        Set<Integer> visitados = new HashSet<>();
        Set<Integer> enProceso = new HashSet<>();

        List<Nodo> nodosInicio = new ArrayList<>();
        for (Nodo n : grafo.getNodos()) {
            if (n.getTipo() != null && "EVENTO".equalsIgnoreCase(n.getTipo())) {
                nodosInicio.add(n);
            }
        }

        if (nodosInicio.isEmpty()) {
            nodosInicio.add(grafo.getNodos().get(0));
        }

        for (Nodo inicio : nodosInicio) {
            recorrerNodo(inicio, mapaNodos, visitados, enProceso, ordenados);
        }

        return ordenados;
    }

    private static void recorrerNodo(
            Nodo nodo,
            Map<Integer, Nodo> mapaNodos,
            Set<Integer> visitados,
            Set<Integer> enProceso,
            List<Nodo> resultado) {
        if (nodo == null) return;

        int id = nodo.getId();
        if (visitados.contains(id)) return;

        if (enProceso.contains(id)) {
            throw new IllegalStateException("Error semántico: Ciclo inválido detectado en el nodo ID: " + id);
        }

        enProceso.add(id);

        if (nodo.getDatosEntrada() != null) {
            for (EntradaDato entrada : nodo.getDatosEntrada().values()) {
                if (entrada != null && "REFERENCIA_NODO".equalsIgnoreCase(entrada.getFuente())
                        && entrada.getIdOrigen() != null) {
                    Nodo nodoOrigen = mapaNodos.get(entrada.getIdOrigen());
                    if (nodoOrigen != null && !visitados.contains(nodoOrigen.getId())) {
                        recorrerNodo(nodoOrigen, mapaNodos, visitados, enProceso, resultado);
                    }
                }
            }
        }

        enProceso.remove(id);
        visitados.add(id);
        resultado.add(nodo);

        if (nodo.getSalidasEjecucion() != null) {
            for (Integer idSiguiente : nodo.getSalidasEjecucion()) {
                if (idSiguiente != null && idSiguiente > 0) {
                    Nodo nodoSiguiente = mapaNodos.get(idSiguiente);
                    if (nodoSiguiente != null && !visitados.contains(nodoSiguiente.getId())) {
                        recorrerNodo(nodoSiguiente, mapaNodos, visitados, enProceso, resultado);
                    }
                }
            }
        }
    }
}


