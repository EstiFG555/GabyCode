/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Class.java to edit this template
 */
package com.mycompany.jvmgabi;

/**
 *
 * @author Agustina
 */

import java.util.*;
//falta call host me llega un nombre y numero, 
//numero es aridad (cantidad de variables que espera la función)
//ver quien maneja la memoria si facu o sho
//llamar a la aplicación que muestra
public class MaquinaVirtual {
    private Stack<Integer> pila;
    private HashMap<String, Integer> memoria;
    
    public MaquinaVirtual() {
        pila = new Stack<>();
        memoria = new HashMap<>();
    }
    
    public void ejecutar(List<String> programa) {
        int pc = 0;
        while (pc < programa.size()) {
            String linea = programa.get(pc).trim();
            if (linea.isEmpty()) {
                pc++;
                continue;
            }
            String[] partes = linea.split(" ");
            String instruccion = partes[0];
            switch (instruccion) {
                case "CALL_HOST" -> {
                String nombreFuncion = partes[1];
                int aridad = Integer.parseInt(partes[2]);

                List<Integer> parametros = new ArrayList<>();

                for (int i = 0; i < aridad; i++) {
                    parametros.add(0, pila.pop());
                }

                int resultado = ejecutarHost(nombreFuncion, parametros);

                pila.push(resultado);
                }
                case "PUSH" -> pila.push(Integer.parseInt(partes[1]));
                case "POP" -> pila.pop();
                case "STORE" -> memoria.put(partes[1], pila.pop());
                case "LOAD" -> pila.push(memoria.get(partes[1]));
                case "ADD" ->  {
                    int b = pila.pop();
                    int a = pila.pop();
                    pila.push(a + b);
                }
                case "SUB" ->  {
                    int b = pila.pop();
                    int a = pila.pop();
                    pila.push(a - b);
                }
                case "MUL" ->  {
                    int b = pila.pop();
                    int a = pila.pop();
                    pila.push(a * b);
                }
                case "DIV" ->  {
                    int b = pila.pop();
                    int a = pila.pop();
                    pila.push(a / b);
                }
                case "EQ" ->  {
                    int b = pila.pop();
                    int a = pila.pop();
                    pila.push(a == b ? 1 : 0);
                }
                case "GT" ->  {
                    int b = pila.pop();
                    int a = pila.pop();
                    pila.push(a > b ? 1 : 0);
                }
                case "LT" ->  {
                    int b = pila.pop();
                    int a = pila.pop();
                    pila.push(a < b ? 1 : 0);
                }
                case "PRINT" -> System.out.println(pila.pop());
                case "JMP" -> {
                    pc = Integer.parseInt(partes[1]);
                    continue;
                }
                case "JMP_IF_TRUE" -> {
                    if (pila.pop() == 1) {
                        pc = Integer.parseInt(partes[1]);
                        continue;
                    }
                }
                case "JMP_IF_FALSE" -> {
                    if (pila.pop() == 0) {
                        pc = Integer.parseInt(partes[1]);
                        continue;
                    }
                }
                case "HALT" -> {
                    return;
                }
                default -> throw new RuntimeException(
                    "Instrucción desconocida: "
                    + instruccion);
            }
            pc++;
        }
    }

    private int ejecutarHost(String nombreFuncion, List<Integer> parametros) {
        switch (nombreFuncion) {
//aca faltaria ver en realidad segun nombre de función que debe ser/ buscar en un archivo a lo mejor 
//el tipo de movimientos que debe hacer
        case "sumar":
            return parametros.get(0) + parametros.get(1);

        case "multiplicar":
            return parametros.get(0) * parametros.get(1);

        case "mostrar":
            System.out.println(parametros.get(0));
            return 0;

        default:
            throw new RuntimeException(
                "Host function no encontrada: "
                + nombreFuncion);
    }
    }
}
