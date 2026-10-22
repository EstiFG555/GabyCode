/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Class.java to edit this template
 */
package gabycodecompiler.escritor;

/**
 *
 * @author facu
 */
import gabycodecompiler.generador.Instruccion;
import java.io.BufferedWriter;
import java.io.FileWriter;
import java.io.IOException;
import java.util.List;

public class EscritorBytecode {

    public static void escribir(List<Instruccion> instrucciones, String rutaSalida) throws IOException {
        if (instrucciones == null) {
            return;
        }

        try (BufferedWriter writer = new BufferedWriter(new FileWriter(rutaSalida))) {
            for (Instruccion inst : instrucciones) {
                String linea;
                if (inst.getOperando() != null && !inst.getOperando().toString().isEmpty()) {
                    linea = inst.getCodigoOperacion().name() + " " + inst.getOperando();
                } else {
                    linea = inst.getCodigoOperacion().name();
                }
                writer.write(linea);
                writer.newLine();
            }
        }
    }
}

