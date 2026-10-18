/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Class.java to edit this template
 */
package gabycodecompiler.lector;

import com.google.gson.Gson;
import gabycodecompiler.modelo.Grafo;
import java.io.FileReader;
import java.io.IOException;

/**
 *
 * @author facu
 */
public class LectorJson {

    public static Grafo cargarGrafo(String rutaArchivo) throws IOException {
        Gson gson = new Gson();

        try (FileReader reader = new FileReader(rutaArchivo)) {
            Grafo grafo = gson.fromJson(reader, Grafo.class);
            return grafo;
        }
    }

    public static Grafo leerGrafo(String rutaArchivo) throws IOException {
        return cargarGrafo(rutaArchivo);
    }
}
