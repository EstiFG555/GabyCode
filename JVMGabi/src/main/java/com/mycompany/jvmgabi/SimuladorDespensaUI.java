/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Class.java to edit this template
 */
package com.mycompany.jvmgabi;

/**
 *
 * @author estif
 */
import com.mycompany.jvmgabi.MaquinaVirtual.Producto;
import java.awt.BorderLayout;
import java.awt.Color;
import java.awt.Dimension;
import java.awt.FlowLayout;
import java.awt.Font;
import java.awt.GridLayout;
import java.io.File;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import javax.swing.BorderFactory;
import javax.swing.BoxLayout;
import javax.swing.JButton;
import javax.swing.JComboBox;
import javax.swing.JFileChooser;
import javax.swing.JFrame;
import javax.swing.JLabel;
import javax.swing.JPanel;
import javax.swing.JScrollPane;
import javax.swing.JSplitPane;
import javax.swing.JTable;
import javax.swing.JTextArea;
import javax.swing.JTextField;
import javax.swing.SwingUtilities;
import javax.swing.event.TableModelEvent;
import javax.swing.table.DefaultTableModel;

public class SimuladorDespensaUI extends JFrame {

    private final MaquinaVirtual vm;
    private final EventBusDespensa eventBus;
    private final DefaultTableModel modeloTabla;
    private final JTable tablaProductos;
    private final JTextArea consolaLog;
    private final JComboBox<String> comboProductoEscaneo;
    private final JTextField inputIdsNavidad;
    private final JTextField inputNuevoId;
    private final JTextField inputNuevoNombre;
    private final JTextField inputNuevoPrecio;
    private final JTextField inputNuevoStock;
    private final JTextField inputVarContextoNombre;
    private final JTextField inputVarContextoValor;
    private Path rutaBytecodeActual;
    private boolean actualizandoTablaInternamente = false;

    public SimuladorDespensaUI() {
        super("Simulador Dinámico de Despensa GabyCode - VM + Event Bus + API Host");
        this.vm = new MaquinaVirtual();
        this.eventBus = new EventBusDespensa(vm);
        this.rutaBytecodeActual = EventBusDespensa.buscarSalidaBytecodePorDefecto();

        setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
        setSize(1180, 740);
        setLocationRelativeTo(null);
        setLayout(new BorderLayout(8, 8));

        // --- 1. PANEL IZQUIERDO: INVENTARIO INTERACTIVO Y ABM DE PRODUCTOS ---
        JPanel panelInventario = new JPanel(new BorderLayout(5, 5));
        panelInventario.setBorder(BorderFactory.createTitledBorder(
                "📦 Inventario Editable en Vivo (Doble clic en Precio/Stock para editar | ☑ Marca ítems para Carrito)"));

        modeloTabla = new DefaultTableModel(new Object[]{"☑ Carrito", "ID", "Producto", "Precio ($)", "Stock"}, 0) {
            @Override
            public Class<?> getColumnClass(int columnIndex) {
                return columnIndex == 0 ? Boolean.class : Object.class;
            }

            @Override
            public boolean isCellEditable(int row, int column) {
                // Permitir marcar el checkbox (col 0) y editar Nombre (col 2), Precio (col 3) y Stock (col 4)
                return column != 1;
            }
        };

        tablaProductos = new JTable(modeloTabla);
        tablaProductos.setRowHeight(25);
        tablaProductos.getColumnModel().getColumn(0).setMaxWidth(75);
        tablaProductos.getColumnModel().getColumn(1).setMaxWidth(60);

        // Escuchar ediciones en vivo sobre las celdas de la tabla para actualizar la VM
        modeloTabla.addTableModelListener((TableModelEvent e) -> {
            if (actualizandoTablaInternamente || e.getType() != TableModelEvent.UPDATE) return;
            int row = e.getFirstRow();
            if (row < 0 || row >= modeloTabla.getRowCount()) return;
            try {
                int id = Integer.parseInt(String.valueOf(modeloTabla.getValueAt(row, 1)));
                Producto p = vm.getCatalogoProductos().get(id);
                if (p != null) {
                    p.nombre = String.valueOf(modeloTabla.getValueAt(row, 2)).trim();
                    String precioStr = String.valueOf(modeloTabla.getValueAt(row, 3)).replace("$", "").replace(",", ".").trim();
                    p.precio = Double.parseDouble(precioStr);
                    p.stock = Integer.parseInt(String.valueOf(modeloTabla.getValueAt(row, 4)).trim());
                    sincronizarComboProductos();
                    agregarLog(String.format("✏️ [Inventario Editado] ID #%d -> %s | Precio: $%.2f | Stock: %d",
                            p.id, p.nombre, p.precio, p.stock));
                }
            } catch (NumberFormatException ex) {
                agregarLog("⚠️ Valor numérico inválido al editar celda. Restaurando vista.");
                refrescarTablaInventario();
            }
        });

        panelInventario.add(new JScrollPane(tablaProductos), BorderLayout.CENTER);

        // Formulario inferior para Agregar / Eliminar Productos en vivo
        JPanel panelAbm = new JPanel(new GridLayout(2, 1, 4, 4));
        JPanel filaInputsProd = new JPanel(new FlowLayout(FlowLayout.LEFT, 4, 2));
        inputNuevoId = new JTextField("105", 4);
        inputNuevoNombre = new JTextField("Yerba Mate 1Kg", 12);
        inputNuevoPrecio = new JTextField("2800", 6);
        inputNuevoStock = new JTextField("10", 4);
        JButton btnAddProd = new JButton("➕ Añadir Producto");
        btnAddProd.addActionListener(e -> agregarProductoDesdeUI());

        filaInputsProd.add(new JLabel("ID:"));
        filaInputsProd.add(inputNuevoId);
        filaInputsProd.add(new JLabel("Nombre:"));
        filaInputsProd.add(inputNuevoNombre);
        filaInputsProd.add(new JLabel("$:"));
        filaInputsProd.add(inputNuevoPrecio);
        filaInputsProd.add(new JLabel("Stock:"));
        filaInputsProd.add(inputNuevoStock);
        filaInputsProd.add(btnAddProd);

        JPanel filaAccionesInv = new JPanel(new GridLayout(1, 2, 6, 2));
        JButton btnEliminarProd = new JButton("🗑️ Eliminar Fila Seleccionada");
        btnEliminarProd.addActionListener(e -> eliminarProductoSeleccionadoUI());
        JButton btnResetInv = new JButton("♻️ Restaurar Inventario Original");
        btnResetInv.addActionListener(e -> {
            vm.inicializarInventarioPorDefecto();
            refrescarTablaInventario();
            sincronizarComboProductos();
            agregarLog("\n[Inventario] Catálogo restaurado a los valores de fábrica.");
        });
        filaAccionesInv.add(btnEliminarProd);
        filaAccionesInv.add(btnResetInv);

        panelAbm.add(filaInputsProd);
        panelAbm.add(filaAccionesInv);
        panelInventario.add(panelAbm, BorderLayout.SOUTH);

        // --- 2. PANEL DERECHO: DISPARADORES DINÁMICOS DEL EVENT BUS Y COMPILADOR ---
        JPanel panelDerecho = new JPanel();
        panelDerecho.setLayout(new BoxLayout(panelDerecho, BoxLayout.Y_AXIS));
        panelDerecho.setBorder(BorderFactory.createTitledBorder("⚡ Event Bus y Pruebas In Situ"));

        // A. Compilación en 1 clic desde Godot
        JPanel panelCompilacion = new JPanel(new GridLayout(1, 2, 5, 5));
        panelCompilacion.setBorder(BorderFactory.createTitledBorder("1. Pipeline Godot -> Bytecode"));
        JButton btnCompilarJson = new JButton("⚙️ Compilar JSON de Godot Ahora");
        btnCompilarJson.setFont(new Font("SansSerif", Font.BOLD, 12));
        btnCompilarJson.addActionListener(e -> compilarJsonDesdeGodot());

        JButton btnElegirBytecode = new JButton("📂 Cargar otro .bytecode...");
        btnElegirBytecode.addActionListener(e -> seleccionarArchivoBytecode());
        panelCompilacion.add(btnCompilarJson);
        panelCompilacion.add(btnElegirBytecode);
        panelDerecho.add(panelCompilacion);

        // B. Evento Escaneo de Producto (Caso 3)
        JPanel panelEscaneo = new JPanel(new BorderLayout(4, 4));
        panelEscaneo.setBorder(BorderFactory.createTitledBorder("2. Evento: ON_PRODUCT_SCANNED"));
        comboProductoEscaneo = new JComboBox<>();
        JButton btnCasoEscaneo = new JButton("📷 Disparar Escaneo con Producto Elegido");
        btnCasoEscaneo.addActionListener(e -> dispararEscaneoProducto());
        panelEscaneo.add(comboProductoEscaneo, BorderLayout.NORTH);
        panelEscaneo.add(btnCasoEscaneo, BorderLayout.CENTER);
        panelDerecho.add(panelEscaneo);

        // C. Evento Finalizar Venta (Caso 1 - Usa los productos marcados con ☑ en la tabla)
        JPanel panelVenta = new JPanel(new BorderLayout(4, 4));
        panelVenta.setBorder(BorderFactory.createTitledBorder("3. Evento: ON_SALE_FINISHED (Usa productos con ☑ en la tabla)"));
        JButton btnCasoVenta = new JButton("🛒 Disparar Finalizar Venta con Carrito Seleccionado (☑)");
        btnCasoVenta.addActionListener(e -> dispararFinalizarVenta());
        panelVenta.add(btnCasoVenta, BorderLayout.CENTER);
        panelDerecho.add(panelVenta);

        // D. Evento Navidad / Lista de IDs (Caso 2 - Permite probar IDs válidos o inexistentes como 999)
        JPanel panelNavidad = new JPanel(new BorderLayout(4, 4));
        panelNavidad.setBorder(BorderFactory.createTitledBorder(
                "4. Evento: ON_CHRISTMAS_PROMO (Escribe IDs separados por coma; ej. 999 para probar Error VM)"));
        inputIdsNavidad = new JTextField("102, 104");
        JButton btnCasoNavidad = new JButton("🎄 Disparar Evento Navidad con Lista de IDs");
        btnCasoNavidad.addActionListener(e -> dispararEventoNavidad());
        panelNavidad.add(inputIdsNavidad, BorderLayout.NORTH);
        panelNavidad.add(btnCasoNavidad, BorderLayout.CENTER);
        panelDerecho.add(panelNavidad);

        // E. Inyector Libre de Contexto para Programas Creados In Situ
        JPanel panelInyector = new JPanel(new FlowLayout(FlowLayout.LEFT, 4, 4));
        panelInyector.setBorder(BorderFactory.createTitledBorder("5. Inyectar Dato Personalizado al Contexto de la VM"));
        inputVarContextoNombre = new JTextField("mi_parametro", 10);
        inputVarContextoValor = new JTextField("100", 8);
        JButton btnInyectarVar = new JButton("💉 Inyectar y Ejecutar Bytecode");
        btnInyectarVar.addActionListener(e -> inyectarDatoYEjecutarLibre());
        panelInyector.add(new JLabel("Clave:"));
        panelInyector.add(inputVarContextoNombre);
        panelInyector.add(new JLabel("Valor:"));
        panelInyector.add(inputVarContextoValor);
        panelInyector.add(btnInyectarVar);
        panelDerecho.add(panelInyector);

        JSplitPane splitSuperior = new JSplitPane(JSplitPane.HORIZONTAL_SPLIT, panelInventario, panelDerecho);
        splitSuperior.setDividerLocation(580);

        // --- 3. PANEL INFERIOR: CONSOLA DE LA MÁQUINA VIRTUAL ---
        JPanel panelConsola = new JPanel(new BorderLayout(4, 4));
        panelConsola.setBorder(BorderFactory.createTitledBorder("🖥️ Consola de Ejecución de la Máquina Virtual y Diagnóstico de Errores"));
        consolaLog = new JTextArea();
        consolaLog.setEditable(false);
        consolaLog.setBackground(new Color(25, 25, 30));
        consolaLog.setForeground(new Color(215, 255, 215));
        consolaLog.setFont(new Font("Consolas", Font.PLAIN, 13));
        JScrollPane scrollConsola = new JScrollPane(consolaLog);
        scrollConsola.setPreferredSize(new Dimension(1100, 240));

        JButton btnLimpiarConsola = new JButton("🧹 Limpiar Consola");
        btnLimpiarConsola.addActionListener(e -> consolaLog.setText(""));
        panelConsola.add(scrollConsola, BorderLayout.CENTER);
        panelConsola.add(btnLimpiarConsola, BorderLayout.EAST);

        vm.setLoggerCallback(this::agregarLog);

        add(splitSuperior, BorderLayout.CENTER);
        add(panelConsola, BorderLayout.SOUTH);

        refrescarTablaInventario();
        sincronizarComboProductos();
        agregarLog("=== Simulador Dinámico GabyCode Iniciado (Catálogo sincronizado con Godot) ===");
        agregarLog("Bytecode activo: " + (rutaBytecodeActual != null ? rutaBytecodeActual.toAbsolutePath() : "Ninguno"));
    }

    private void agregarProductoDesdeUI() {
        try {
            int id = Integer.parseInt(inputNuevoId.getText().trim());
            String nombre = inputNuevoNombre.getText().trim();
            double precio = Double.parseDouble(inputNuevoPrecio.getText().replace(",", ".").trim());
            int stock = Integer.parseInt(inputNuevoStock.getText().trim());
            if (nombre.isEmpty()) return;

            Producto nuevo = new Producto(id, nombre, precio, stock);
            vm.getCatalogoProductos().put(id, nuevo);
            refrescarTablaInventario();
            sincronizarComboProductos();
            inputNuevoId.setText(String.valueOf(id + 1));
            agregarLog("➕ [Inventario] Nuevo producto registrado: " + nuevo);
        } catch (NumberFormatException ex) {
            agregarLog("⚠️ Error al crear producto: Verifica que ID, Precio y Stock sean numéricos.");
        }
    }

    private void eliminarProductoSeleccionadoUI() {
        int fila = tablaProductos.getSelectedRow();
        if (fila < 0) {
            agregarLog("ℹ️ Selecciona una fila en la tabla de inventario para eliminarla.");
            return;
        }
        int id = Integer.parseInt(String.valueOf(modeloTabla.getValueAt(fila, 1)));
        Producto eliminado = vm.getCatalogoProductos().remove(id);
        refrescarTablaInventario();
        sincronizarComboProductos();
        if (eliminado != null) {
            agregarLog("🗑️ [Inventario] Producto eliminado: " + eliminado.nombre + " (ID #" + id + ")");
        }
    }

    private void sincronizarComboProductos() {
        comboProductoEscaneo.removeAllItems();
        for (Producto p : vm.getCatalogoProductos().values()) {
            comboProductoEscaneo.addItem(p.id + " - " + p.nombre + " ($" + p.precio + " | Stock: " + p.stock + ")");
        }
    }

    private List<Producto> obtenerProductosMarcadosEnTabla() {
        List<Producto> seleccionados = new ArrayList<>();
        for (int i = 0; i < modeloTabla.getRowCount(); i++) {
            Boolean marcado = (Boolean) modeloTabla.getValueAt(i, 0);
            if (Boolean.TRUE.equals(marcado)) {
                int id = Integer.parseInt(String.valueOf(modeloTabla.getValueAt(i, 1)));
                Producto p = vm.getCatalogoProductos().get(id);
                if (p != null) seleccionados.add(p);
            }
        }
        return seleccionados;
    }

    private void dispararEscaneoProducto() {
        if (comboProductoEscaneo.getSelectedItem() == null) return;
        String item = String.valueOf(comboProductoEscaneo.getSelectedItem());
        int idProd = Integer.parseInt(item.split("-")[0].trim());
        Producto seleccionado = vm.getCatalogoProductos().get(idProd);

        agregarLog("\n------------------------------------------------------------");
        agregarLog("🔔 [EVENT BUS] Publicando ON_PRODUCT_SCANNED -> " + seleccionado);
        Map<String, Object> payload = new HashMap<>();
        payload.put("ProductoActual", seleccionado);
        payload.put("producto_leido", seleccionado);

        eventBus.publicarEvento("ON_PRODUCT_SCANNED", payload, rutaBytecodeActual);
        refrescarTablaInventario();
        sincronizarComboProductos();
    }

    private void dispararFinalizarVenta() {
        List<Producto> carrito = obtenerProductosMarcadosEnTabla();
        agregarLog("\n------------------------------------------------------------");
        agregarLog("🔔 [EVENT BUS] Publicando ON_SALE_FINISHED -> Carrito (" + carrito.size() + " ítems): " + carrito);
        Map<String, Object> payload = new HashMap<>();
        payload.put("lista_productos", carrito);

        eventBus.publicarEvento("ON_SALE_FINISHED", payload, rutaBytecodeActual);
        refrescarTablaInventario();
        sincronizarComboProductos();
    }

    private void dispararEventoNavidad() {
        List<Integer> idsNavidad = new ArrayList<>();
        String raw = inputIdsNavidad.getText().trim();
        if (!raw.isEmpty()) {
            for (String parte : raw.split(",")) {
                try {
                    idsNavidad.add(Integer.parseInt(parte.trim()));
                } catch (NumberFormatException ex) {
                    agregarLog("⚠️ ID no numérico ignorado en la lista: '" + parte + "'");
                }
            }
        }

        agregarLog("\n------------------------------------------------------------");
        agregarLog("🔔 [EVENT BUS] Publicando ON_CHRISTMAS_PROMO -> IDs enviados: " + idsNavidad);
        Map<String, Object> payload = new HashMap<>();
        payload.put("lista_ids_descuento", idsNavidad);

        eventBus.publicarEvento("ON_CHRISTMAS_PROMO", payload, rutaBytecodeActual);
        refrescarTablaInventario();
        sincronizarComboProductos();
    }

    private void inyectarDatoYEjecutarLibre() {
        String clave = inputVarContextoNombre.getText().trim();
        String valorRaw = inputVarContextoValor.getText().trim();
        Object valorInterpretado = valorRaw;
        try {
            valorInterpretado = Integer.parseInt(valorRaw);
        } catch (NumberFormatException e1) {
            try {
                valorInterpretado = Double.parseDouble(valorRaw);
            } catch (NumberFormatException ignored) {
            }
        }

        Map<String, Object> payload = new HashMap<>();
        if (!clave.isEmpty()) {
            payload.put(clave, valorInterpretado);
        }
        agregarLog("\n------------------------------------------------------------");
        agregarLog("🔔 [EVENT BUS] Ejecución In Situ con contexto inyectado: " + payload);
        eventBus.publicarEvento("CUSTOM_EVENT", payload, rutaBytecodeActual);
        refrescarTablaInventario();
        sincronizarComboProductos();
    }

    private void compilarJsonDesdeGodot() {
        try {
            File jsonFile = new File("../GabyCodeCompilador/GabyCodeCompiler/src/main/java/archivos_prueba/flujo_prueba.json");
            File outFile = new File("../GabyCodeCompilador/GabyCodeCompiler/src/main/java/archivos_prueba/salida.bytecode");
            File classesDir = new File("../GabyCodeCompilador/GabyCodeCompiler/target/classes");

            if (!jsonFile.exists()) {
                agregarLog("⚠️ No se encontró flujo_prueba.json en la ruta relativa del compilador.");
                return;
            }

            String userHome = System.getProperty("user.home");
            String gsonJar = userHome + File.separator + ".m2" + File.separator + "repository"
                    + File.separator + "com" + File.separator + "google" + File.separator + "code"
                    + File.separator + "gson" + File.separator + "gson" + File.separator + "2.10.1"
                    + File.separator + "gson-2.10.1.jar";

            String cp = classesDir.getAbsolutePath() + File.pathSeparator + gsonJar;
            ProcessBuilder pb = new ProcessBuilder(
                    "java", "-cp", cp, "gabycodecompilador.main",
                    jsonFile.getAbsolutePath(), outFile.getAbsolutePath()
            );
            pb.redirectErrorStream(true);
            Process proc = pb.start();
            String salidaCompilador = new String(proc.getInputStream().readAllBytes());
            proc.waitFor();

            rutaBytecodeActual = outFile.toPath();
            agregarLog("\n⚙️ [Compilador Ejecutado sobre el JSON de Godot]:\n" + salidaCompilador);
        } catch (Exception ex) {
            agregarLog("⚠️ Error al invocar el compilador automáticamente: " + ex.getMessage());
        }
    }

    private void seleccionarArchivoBytecode() {
        JFileChooser chooser = new JFileChooser(new File("."));
        if (chooser.showOpenDialog(this) == JFileChooser.APPROVE_OPTION) {
            rutaBytecodeActual = chooser.getSelectedFile().toPath();
            agregarLog("\n📂 Nuevo archivo Bytecode activo: " + rutaBytecodeActual.toAbsolutePath());
        }
    }

    private void refrescarTablaInventario() {
        actualizandoTablaInternamente = true;
        // Conservar cuáles IDs estaban marcados antes de refrescar
        Map<Integer, Boolean> seleccionadosPrevios = new HashMap<>();
        for (int i = 0; i < modeloTabla.getRowCount(); i++) {
            int id = Integer.parseInt(String.valueOf(modeloTabla.getValueAt(i, 1)));
            seleccionadosPrevios.put(id, (Boolean) modeloTabla.getValueAt(i, 0));
        }

        modeloTabla.setRowCount(0);
        for (Producto p : vm.getCatalogoProductos().values()) {
            boolean marcadoPorDefecto = seleccionadosPrevios.getOrDefault(p.id, (p.id == 101 || p.id == 103));
            modeloTabla.addRow(new Object[]{
                marcadoPorDefecto,
                p.id,
                p.nombre,
                String.format("%.2f", p.precio),
                p.stock
            });
        }
        actualizandoTablaInternamente = false;
    }

    private void agregarLog(String linea) {
        consolaLog.append(linea + "\n");
        consolaLog.setCaretPosition(consolaLog.getDocument().getLength());
    }

    public static void iniciarVentana() {
        SwingUtilities.invokeLater(() -> {
            new SimuladorDespensaUI().setVisible(true);
        });
    }
}