/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Class.java to edit this template
 */
package gabycodecompiler.generador;

import gabycodecompiler.modelo.EntradaDato;
import gabycodecompiler.modelo.Nodo;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 *
 * @author facu
 */
public class GeneradorBytecode {

    public static List<Instruccion> generar(List<Nodo> nodosOrdenados) {
        List<Instruccion> instrucciones = new ArrayList<>();

        if (nodosOrdenados == null || nodosOrdenados.isEmpty()) {
            return instrucciones;
        }

        for (Nodo nodo : nodosOrdenados) {
            String operacion = nodo.getOperacion() != null ? nodo.getOperacion().toUpperCase() : "";

            // 1. Apilar los operandos directos (LITERALES y VARIABLES)
            // Las REFERENCIAS_NODO ya depositaron su valor en la pila en pasos anteriores
            cargarEntradasDirectas(nodo, instrucciones);
            
            switch (operacion) {
                // --- EXPRESIONES Y MATEMÁTICA ---
                case "GET_STOCK":
                    instrucciones.add(new Instruccion(CodigoOperacion.CALL_HOST, "GET_STOCK"));
                    break;

                case "LESS_THAN":
                case "OP_CMP_LT":
                    instrucciones.add(new Instruccion(CodigoOperacion.OP_CMP_LT));
                    break;

                case "GREATER_THAN":
                case "OP_CMP_GT":
                    instrucciones.add(new Instruccion(CodigoOperacion.OP_CMP_GT));
                    break;

                case "EQUAL":
                case "OP_CMP_EQ":
                    instrucciones.add(new Instruccion(CodigoOperacion.OP_CMP_EQ));
                    break;

                case "ADD":
                case "OP_ADD":
                    instrucciones.add(new Instruccion(CodigoOperacion.OP_ADD));
                    break;

                case "SUB":
                case "OP_SUB":
                    instrucciones.add(new Instruccion(CodigoOperacion.OP_SUB));
                    break;

                // --- CONTROL DE FLUJO ---
                case "IF_ELSE":
                    // Consume el booleano en la cima de la pila. Si es falso, salta
                    instrucciones.add(new Instruccion(CodigoOperacion.JUMP_IF_FALSE, "OFFSET_ELSE"));
                    break;

                // --- ACCIONES DE GODOT / HOST ---
                case "SHOW_ALERT":
                    instrucciones.add(new Instruccion(CodigoOperacion.CALL_HOST, "SHOW_ALERT"));
                    break;

                case "APPLY_DISCOUNT":
                    instrucciones.add(new Instruccion(CodigoOperacion.CALL_HOST, "APPLY_DISCOUNT"));
                    break;

                // --- EVENTOS / DISPARADORES ---
                case "ON_PRODUCT_SCANNED":
                    // Evento disparador de inicio
                    break;

                default:
                    if (nodo.getTipo() != null && "ACCION".equalsIgnoreCase(nodo.getTipo().toString())) {
                        instrucciones.add(new Instruccion(CodigoOperacion.CALL_HOST, operacion));
                    }
                    break;
            }
        }

        // Finalización de la rutina
        instrucciones.add(new Instruccion(CodigoOperacion.HALT));

        return instrucciones;
    }

    private static void cargarEntradasDirectas(Nodo nodo, List<Instruccion> instrucciones) {
        if (nodo.getDatosEntrada() == null) return;

        for (Map.Entry<String, EntradaDato> entry : nodo.getDatosEntrada().entrySet()) {
            EntradaDato entrada = entry.getValue();
            if (entrada == null) continue;

            String fuente = entrada.getFuente();
            if ("LITERAL".equalsIgnoreCase(fuente)) {
                instrucciones.add(new Instruccion(CodigoOperacion.PUSH_LITERAL, entrada.getValor()));
            } else if ("VARIABLE".equalsIgnoreCase(fuente)) {
                instrucciones.add(new Instruccion(CodigoOperacion.LOAD_VAR, entrada.getNombre()));
            }
        }
    }
}
