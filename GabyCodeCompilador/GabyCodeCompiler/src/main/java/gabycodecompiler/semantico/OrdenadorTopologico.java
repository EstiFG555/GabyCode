/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Class.java to edit this template
 */
package gabycodecompiler.semantico;

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

/**
 *
 * @author facu
 */
public class OrdenadorTopologico {
    
    //Tipo nodo = `CONTROL`, `EXPRESION`, `ACCION`, `EVENTO`
    
    public static List<Nodo> ordenar(Grafo grafo){
        if(grafo == null || grafo.getNodos() == null || grafo.getNodos().isEmpty()){
            return Collections.emptyList();
        }
        
        Map<Integer, Nodo> mapaNodos = new HashMap<>();
        
        for (Nodo n: grafo.getNodos()){
            mapaNodos.put(n.getId(), n);
        }
        
        List <Nodo> ordenados = new ArrayList<>();
        Set<Integer> visitados = new HashSet<>();
        Set<Integer> enProceso = new HashSet<>();
        
        //indentificacion de nodos de incios para comenzar a ordenar
        List<Nodo> nodosInicio = new ArrayList<>();
        for (Nodo n : grafo.getNodos()) {
            if(n.getTipo() != null && "EVENTO".equalsIgnoreCase(n.getTipo().toString())){
                nodosInicio.add(n);
            }
        }
        //Si no hay un nodo de tipo  evento usamos el primer nodo arbitrariamente
        if(nodosInicio.isEmpty()){
            nodosInicio.add(grafo.getNodos().get(0));
        }
        
        //Se comienza el ordenamiento
        for (Nodo inicio: nodosInicio){
            recorrerNodo(inicio, mapaNodos, visitados, enProceso, ordenados);
        }
        
        return ordenados;
    }
    
    private static void recorrerNodo(
            Nodo nodo, 
            Map<Integer, Nodo> mapaNodos, 
            Set<Integer> visitados, 
            Set<Integer> enProceso,
            List<Nodo> resultado)
    {
        if (nodo == null) return;
        
        int id = nodo.getId();
        
        if (visitados.contains(id)){
            return; //nodo ya visitado y agregado a ordenados
        }
        
        if(enProceso.contains(id)){
            throw new IllegalStateException("Error semantico: Ciclo detectado en las dependencias del nodo ID: " + id);
        }
        
        enProceso.add(id);
        
        //Primero se resuelven las dependencias de datos
        //lo que este nodo necesita consumir
        
        if(nodo.getDatosEntrada() != null){
            for (EntradaDato entrada : nodo.getDatosEntrada().values()){
                if("REFERENCIA_NODO".equalsIgnoreCase(entrada.getFuente())&&
                        entrada.getIdOrigen() != null){ //si es una entrada de referencia
                    Nodo nodoOrigen = mapaNodos.get(entrada.getIdOrigen());
                    if (nodoOrigen != null && !visitados.contains(nodoOrigen.getId())){
                        //si existe el nodo y si no lo visitamos
                        recorrerNodo(nodoOrigen, mapaNodos, visitados, enProceso, resultado);
                    }
                }
            }
        }
        
        //ya visitados todos los nodos necesarios por cada entrada se vuelve atras 
        //en cada retroceso se guarda el nodo necesario a consumir.
        
        enProceso.remove(id);
        visitados.add(id);
        resultado.add(nodo);
        
        //Segundo se resuelven los siguientes nodos a visitar (los salida_ejecucion)
        
        if(nodo.getSalidasEjecucion()!=null){
            for(Integer idSiguiente: nodo.getSalidasEjecucion()){
                Nodo nodoSiguiente = mapaNodos.get(idSiguiente);
                if(nodoSiguiente != null && !visitados.contains(nodoSiguiente.getId())){
                    recorrerNodo(nodoSiguiente, mapaNodos, visitados, enProceso, resultado);
                }
            }
        }
    }
}


