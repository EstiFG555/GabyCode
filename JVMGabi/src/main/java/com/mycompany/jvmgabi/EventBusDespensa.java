/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Class.java to edit this template
 */
package com.mycompany.jvmgabi;

/**
 *
 * @author estif
 */
import java.io.File;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class EventBusDespensa {

    private final MaquinaVirtual vm;
    private final Map<String, Path> suscripcionesBytecode;

    public EventBusDespensa(MaquinaVirtual vm) {
        this.vm = vm;
        this.suscripcionesBytecode = new HashMap<>();
    }

    public void suscribirEvento(String nombreEvento, Path rutaBytecode) {
        suscripcionesBytecode.put(nombreEvento.toUpperCase(), rutaBytecode);
    }

    public void publicarEvento(String nombreEvento, Map<String, Object> datosContexto, Path rutaBytecodeActiva) {
        try {
            if (datosContexto != null) {
                for (Map.Entry<String, Object> entry : datosContexto.entrySet()) {
                    vm.inyectarDatoEvento(entry.getKey(), entry.getValue());
                }
            }

            Path archivoAEjecutar = suscripcionesBytecode.getOrDefault(nombreEvento.toUpperCase(), rutaBytecodeActiva);
            if (archivoAEjecutar == null || !Files.exists(archivoAEjecutar)) {
                archivoAEjecutar = buscarSalidaBytecodePorDefecto();
            }

            if (archivoAEjecutar != null && Files.exists(archivoAEjecutar)) {
                List<String> instrucciones = Files.readAllLines(archivoAEjecutar);
                vm.ejecutar(instrucciones);
            } else {
                System.err.println("[EventBus] No se encontró archivo .bytecode para el evento " + nombreEvento);
            }
        } catch (Exception ex) {
            System.err.println("[EventBus Error] Fallo al ejecutar evento " + nombreEvento + ": " + ex.getMessage());
        }
    }

    public static Path buscarSalidaBytecodePorDefecto() {
        String[] rutas = {
            "../GabyCodeCompilador/GabyCodeCompiler/src/main/java/archivos_prueba/salida.bytecode",
            "GabyCodeCompilador/GabyCodeCompiler/src/main/java/archivos_prueba/salida.bytecode",
            "salida.bytecode",
            "PruebaDeGaston.GabyCode"
        };
        for (String r : rutas) {
            File f = new File(r);
            if (f.exists()) return f.toPath();
        }
        return null;
    }
}