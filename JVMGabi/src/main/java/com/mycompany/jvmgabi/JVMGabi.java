/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 */

package com.mycompany.jvmgabi;


/**
 *
 * @author Agustina
 */
import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.List;

public class JVMGabi {

    public static void main(String[] args) throws IOException {
        Path rutaElegida = resolverRutaBytecode(args);

        System.out.println("==========================================");
        System.out.println(" Iniciando JVMGabi - Archivo: " + rutaElegida.toAbsolutePath());
        System.out.println("==========================================\n");

        List<String> programa = Files.readAllLines(rutaElegida);
        MaquinaVirtual vm = new MaquinaVirtual();
        vm.ejecutar(programa);
    }

    private static Path resolverRutaBytecode(String[] args) {
        // 1. Si se pasa ruta por argumento de línea de comandos, usarla
        if (args != null && args.length > 0 && !args[0].isBlank()) {
            File f = new File(args[0]);
            if (f.exists()) {
                return f.toPath();
            }
        }

        // 2. Buscar automáticamente el salida.bytecode generado por GabyCodeCompilador
        String[] rutasCandidatas = {
            "../GabyCodeCompilador/GabyCodeCompiler/src/main/java/archivos_prueba/salida.bytecode",
            "GabyCodeCompilador/GabyCodeCompiler/src/main/java/archivos_prueba/salida.bytecode",
            "salida.bytecode",
            "PruebaDeGaston.GabyCode"
        };

        for (String ruta : rutasCandidatas) {
            File archivo = new File(ruta);
            if (archivo.exists()) {
                return archivo.toPath();
            }
        }

        return Paths.get("PruebaDeGaston.GabyCode");
    }
}
