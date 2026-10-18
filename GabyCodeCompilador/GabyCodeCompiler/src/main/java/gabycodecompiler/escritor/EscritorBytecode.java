/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Class.java to edit this template
 */
package gabycodecompiler.escritor;

import gabycodecompiler.generador.Instruccion;
import java.io.BufferedWriter;
import java.io.FileWriter;
import java.io.IOException;
import java.util.List;

/**
 *
 * @author facu
 */
public class EscritorBytecode {
    
    public static void escribir(List<Instruccion> instrucciones, String rutaSalida) throws IOException {
        if (instrucciones == null) {
            return;
        }

        try (BufferedWriter writer = new BufferedWriter(new FileWriter(rutaSalida))) {
            for (int i = 0; i < instrucciones.size(); i++) {
                Instruccion inst = instrucciones.get(i);
                // Formato con offset numérico alineado y la instrucción traducida
                String linea = String.format("[%04d] %s %s", i, inst.getCodigoOperacion(), inst.getOperando());
                writer.write(linea);
                writer.newLine();
            }
        }
    }
}

