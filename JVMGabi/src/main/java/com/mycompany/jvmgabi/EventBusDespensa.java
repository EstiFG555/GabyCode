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
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public class EventBusDespensa {

    public static class SalidaPuerto {
        public final String nombrePuerto;
        public final String tipo;
        public final String subtipo; // Opcional si tipo == "ARRAY"

        public SalidaPuerto(String nombrePuerto, String tipo, String subtipo) {
            this.nombrePuerto = nombrePuerto;
            this.tipo = tipo;
            this.subtipo = subtipo;
        }
    }

    public static class DefinicionEvento {
        public final String codigoOperacion;
        public final String nombreVisual;
        public final List<SalidaPuerto> salidas = new ArrayList<>();

        public DefinicionEvento(String codigoOperacion, String nombreVisual) {
            this.codigoOperacion = codigoOperacion;
            this.nombreVisual = nombreVisual;
        }

        public DefinicionEvento conSalida(String nombrePuerto, String tipo) {
            salidas.add(new SalidaPuerto(nombrePuerto, tipo, null));
            return this;
        }

        public DefinicionEvento conSalidaArray(String nombrePuerto, String subtipo) {
            salidas.add(new SalidaPuerto(nombrePuerto, "ARRAY", subtipo));
            return this;
        }
    }

    public static class DefinicionAccionHost {
        public final String codigoOperacion;
        public final String nombreVisual;
        public final Map<String, String> entradasOrdenadas = new LinkedHashMap<>();
        public final List<SalidaPuerto> salidas = new ArrayList<>();

        public DefinicionAccionHost(String codigoOperacion, String nombreVisual) {
            this.codigoOperacion = codigoOperacion;
            this.nombreVisual = nombreVisual;
        }

        public DefinicionAccionHost conEntrada(String nombreParam, String tipo) {
            entradasOrdenadas.put(nombreParam, tipo);
            return this;
        }

        public DefinicionAccionHost conSalida(String nombrePuerto, String tipo) {
            salidas.add(new SalidaPuerto(nombrePuerto, tipo, null));
            return this;
        }
    }

    private final MaquinaVirtual vm;
    private final Map<String, Path> suscripcionesBytecode = new LinkedHashMap<>();
    private final List<String> tiposObjetosRegistrados = new ArrayList<>();
    private final Map<String, DefinicionEvento> eventosRegistrados = new LinkedHashMap<>();
    private final Map<String, DefinicionAccionHost> accionesHostRegistradas = new LinkedHashMap<>();

    public EventBusDespensa(MaquinaVirtual vm) {
        this.vm = vm;
        inicializarCatalogoDominio();
        exportarCatalogoHaciaGodot();
    }

    /**
     * FUENTE ÚNICA DE LA VERDAD (SINGLE SOURCE OF TRUTH):
     * Cualquier objeto, señal de evento o función CALL_HOST agregada aquí por los programadores
     * de Java se exporta automáticamente a catalogo_host.json para el editor de Godot.
     */
    private void inicializarCatalogoDominio() {
        // 1. Objetos del modelo de dominio reconocidos por el sistema de tipos
        tiposObjetosRegistrados.addAll(Arrays.asList("PRODUCTO", "VENTA", "CLIENTE"));

        // 2. Señales del Event Bus y los datos que traen al contexto (Scope)
        registrarEvento(new DefinicionEvento("ON_PRODUCT_SCANNED", "Evento: Al Escanear Producto")
                .conSalida("producto_leido", "PRODUCTO"));

        registrarEvento(new DefinicionEvento("ON_SALE_FINISHED", "Evento: Finalizar Venta")
                .conSalidaArray("lista_productos", "PRODUCTO"));

        registrarEvento(new DefinicionEvento("ON_CHRISTMAS_PROMO", "Evento: Se acerca Navidad")
                .conSalidaArray("lista_ids_descuento", "INT"));

        registrarEvento(new DefinicionEvento("SUBROUTINE_ENTRY", "Inicio de Subrutina (Acción Compuesta)")
                .conSalida("parametro_entrada", "ANY"));

        // 3. Catálogo de Funciones Nativas (API CALL_HOST) provistas a la Administradora
        registrarAccionHost(new DefinicionAccionHost("GET_STOCK", "Obtener Stock de Producto")
                .conEntrada("producto", "PRODUCTO")
                .conSalida("resultado", "INT"));

        registrarAccionHost(new DefinicionAccionHost("GET_PRODUCT_BY_ID", "Obtener Producto")
                .conEntrada("id_producto", "INT")
                .conSalida("producto", "PRODUCTO"));

        registrarAccionHost(new DefinicionAccionHost("APPLY_DISCOUNT", "Aplicar Descuento")
                .conEntrada("producto", "PRODUCTO")
                .conEntrada("porcentaje", "INT"));

        registrarAccionHost(new DefinicionAccionHost("SHOW_ALERT", "Mostrar Mensaje / Alerta")
                .conEntrada("mensaje", "STRING"));

        registrarAccionHost(new DefinicionAccionHost("CALCULATE_SALE_TOTAL", "Calcular Total de Venta")
                .conEntrada("lista_productos", "ARRAY")
                .conSalida("total", "FLOAT"));

        registrarAccionHost(new DefinicionAccionHost("REGISTER_SALE", "Registrar Venta")
                .conEntrada("lista_productos", "ARRAY")
                .conEntrada("total", "FLOAT"));

        registrarAccionHost(new DefinicionAccionHost("SHOW_TOTAL", "Mostrar Total")
                .conEntrada("total", "FLOAT"));
    }

    public void registrarEvento(DefinicionEvento def) {
        eventosRegistrados.put(def.codigoOperacion.toUpperCase(), def);
    }

    public void registrarAccionHost(DefinicionAccionHost def) {
        accionesHostRegistradas.put(def.codigoOperacion.toUpperCase(), def);
    }

    public Map<String, DefinicionEvento> getEventosRegistrados() {
        return eventosRegistrados;
    }

    public Map<String, DefinicionAccionHost> getAccionesHostRegistradas() {
        return accionesHostRegistradas;
    }

    public void suscribirEvento(String nombreEvento, Path rutaBytecode) {
        suscripcionesBytecode.put(nombreEvento.toUpperCase(), rutaBytecode);
    }

    public boolean publicarEvento(String nombreEvento, Map<String, Object> datosContexto, Path rutaBytecodeActiva) {
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
                return vm.ejecutar(instrucciones);
            } else {
                System.err.println("[EventBus] No se encontró archivo .bytecode para el evento " + nombreEvento);
                return false;
            }
        } catch (IOException ex) {
            System.err.println("[EventBus Error] Fallo al leer bytecode para " + nombreEvento + ": " + ex.getMessage());
            return false;
        }
    }

    public final void exportarCatalogoHaciaGodot() {
        String[] rutasDestino = {
            "../compilador-gráfico/catalogo_host.json",
            "compilador-gráfico/catalogo_host.json"
        };
        String jsonGenerado = construirJsonCatalogo();
        for (String ruta : rutasDestino) {
            File f = new File(ruta);
            if (f.getParentFile() != null && f.getParentFile().exists()) {
                try {
                    Files.writeString(f.toPath(), jsonGenerado, StandardCharsets.UTF_8);
                } catch (IOException ignored) {
                }
            }
        }
    }

    private String construirJsonCatalogo() {
        StringBuilder sb = new StringBuilder();
        sb.append("{\n\t\"tipos_objetos\": [\n");
        for (int i = 0; i < tiposObjetosRegistrados.size(); i++) {
            sb.append("\t\t\"").append(tiposObjetosRegistrados.get(i)).append("\"");
            if (i < tiposObjetosRegistrados.size() - 1) sb.append(",");
            sb.append("\n");
        }
        sb.append("\t],\n\t\"eventos\": [\n");
        int evIdx = 0;
        for (DefinicionEvento ev : eventosRegistrados.values()) {
            sb.append("\t\t{\n");
            sb.append("\t\t\t\"operacion\": \"").append(ev.codigoOperacion).append("\",\n");
            sb.append("\t\t\t\"nombre_visual\": \"").append(ev.nombreVisual).append("\",\n");
            sb.append("\t\t\t\"salidas\": {");
            for (int j = 0; j < ev.salidas.size(); j++) {
                SalidaPuerto sp = ev.salidas.get(j);
                sb.append("\n\t\t\t\t\"").append(sp.nombrePuerto).append("\": { \"tipo\": \"").append(sp.tipo).append("\"");
                if (sp.subtipo != null) {
                    sb.append(", \"subtipo\": \"").append(sp.subtipo).append("\"");
                }
                sb.append(" }");
                if (j < ev.salidas.size() - 1) sb.append(",");
            }
            sb.append("\n\t\t\t}\n\t\t}");
            if (++evIdx < eventosRegistrados.size()) sb.append(",");
            sb.append("\n");
        }
        sb.append("\t],\n\t\"acciones\": [\n");
        int accIdx = 0;
        for (DefinicionAccionHost acc : accionesHostRegistradas.values()) {
            sb.append("\t\t{\n");
            sb.append("\t\t\t\"operacion\": \"").append(acc.codigoOperacion).append("\",\n");
            sb.append("\t\t\t\"nombre_visual\": \"").append(acc.nombreVisual).append("\",\n");
            sb.append("\t\t\t\"orden_entradas\": [");
            List<String> keys = new ArrayList<>(acc.entradasOrdenadas.keySet());
            for (int j = 0; j < keys.size(); j++) {
                sb.append("\"").append(keys.get(j)).append("\"");
                if (j < keys.size() - 1) sb.append(", ");
            }
            sb.append("],\n\t\t\t\"entradas\": {");
            for (int j = 0; j < keys.size(); j++) {
                String k = keys.get(j);
                sb.append("\n\t\t\t\t\"").append(k).append("\": \"").append(acc.entradasOrdenadas.get(k)).append("\"");
                if (j < keys.size() - 1) sb.append(",");
            }
            sb.append("\n\t\t\t},\n\t\t\t\"salidas\": {");
            for (int j = 0; j < acc.salidas.size(); j++) {
                SalidaPuerto sp = acc.salidas.get(j);
                sb.append("\n\t\t\t\t\"").append(sp.nombrePuerto).append("\": { \"tipo\": \"").append(sp.tipo).append("\" }");
                if (j < acc.salidas.size() - 1) sb.append(",");
            }
            sb.append("\n\t\t\t}\n\t\t}");
            if (++accIdx < accionesHostRegistradas.size()) sb.append(",");
            sb.append("\n");
        }
        sb.append("\t]\n}");
        return sb.toString();
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