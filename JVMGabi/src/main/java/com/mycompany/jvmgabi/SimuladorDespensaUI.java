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
import java.awt.Font;
import java.awt.GridLayout;
import java.io.File;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import javax.swing.BorderFactory;
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
import javax.swing.SwingUtilities;
import javax.swing.table.DefaultTableModel;

public class SimuladorDespensaUI extends JFrame {

    private final MaquinaVirtual vm;
    private final EventBusDespensa eventBus;
    private final DefaultTableModel modeloTabla;
    private final JTextArea consolaLog;
    private final JComboBox<String> comboProductoEscaneo;
    private Path rutaBytecodeActual;

    public SimuladorDespensaUI() {
        super("Simulador de Despensa GabyCode - Entorno de Ejecución (VM + Event Bus)");
        this.vm = new MaquinaVirtual();
        this.eventBus = new EventBusDespensa(vm);
        this.rutaBytecodeActual = EventBusDespensa.buscarSalidaBytecodePorDefecto();

        setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
        setSize(1050, 680);
        setLocationRelativeTo(null);
        setLayout(new BorderLayout(10, 10));

        // 1. Panel Izquierdo: Tabla de Inventario en Vivo
        JPanel panelInventario = new JPanel(new BorderLayout(5, 5));
        panelInventario.setBorder(BorderFactory.createTitledBorder("📦 Inventario de la Despensa (Tiempo Real)"));

        modeloTabla = new DefaultTableModel(new Object[]{"ID", "Producto", "Precio ($)", "Stock"}, 0) {
            @Override
            public boolean isCellEditable(int row, int column) {
                return false;
            }
        };
        JTable tablaProductos = new JTable(modeloTabla);
        tablaProductos.setRowHeight(26);
        panelInventario.add(new JScrollPane(tablaProductos), BorderLayout.CENTER);

        JPanel panelBotonesInv = new JPanel(new GridLayout(1, 2, 5, 5));
        JButton btnAlternarStock = new JButton("🔄 Alternar Stock Leche (3 ↔ 20)");
        btnAlternarStock.addActionListener(e -> {
            Producto leche = vm.getCatalogoProductos().get(101);
            if (leche != null) {
                leche.stock = (leche.stock < 5) ? 20 : 3;
                refrescarTablaInventario();
                agregarLog("\n[Inventario] Stock de '" + leche.nombre + "' ajustado a " + leche.stock + " unidades.");
            }
        });
        JButton btnResetInv = new JButton("♻️ Restaurar Inventario Inicial");
        btnResetInv.addActionListener(e -> {
            vm.inicializarInventarioPorDefecto();
            refrescarTablaInventario();
            agregarLog("\n[Inventario] Precios y stocks restaurados a sus valores originales.");
        });
        panelBotonesInv.add(btnAlternarStock);
        panelBotonesInv.add(btnResetInv);
        panelInventario.add(panelBotonesInv, BorderLayout.SOUTH);

        // 2. Panel Derecho: Disparadores del Event Bus (Los 3 Casos de Prueba)
        JPanel panelEventos = new JPanel(new GridLayout(5, 1, 8, 8));
        panelEventos.setBorder(BorderFactory.createTitledBorder("⚡ Event Bus: Disparadores de Casos de Prueba"));

        // Selector y Botón Caso 3: ON_PRODUCT_SCANNED
        JPanel panelEscaneo = new JPanel(new BorderLayout(5, 5));
        comboProductoEscaneo = new JComboBox<>(new String[]{
            "101 - Leche Entera 1L",
            "102 - Pan Dulce Navideño",
            "103 - Arroz Grano Largo 1Kg",
            "104 - Sidra Etiqueta Blanca"
        });
        JButton btnCasoEscaneo = new JButton("📷 Disparar: Al Escanear Producto (ON_PRODUCT_SCANNED)");
        btnCasoEscaneo.addActionListener(e -> dispararEscaneoProducto());
        panelEscaneo.add(comboProductoEscaneo, BorderLayout.NORTH);
        panelEscaneo.add(btnCasoEscaneo, BorderLayout.CENTER);
        panelEventos.add(panelEscaneo);

        // Botón Caso 1: ON_SALE_FINISHED
        JButton btnCasoVenta = new JButton("🛒 Disparar: Finalizar Venta (ON_SALE_FINISHED - Carrito: Leche + Arroz)");
        btnCasoVenta.addActionListener(e -> dispararFinalizarVenta());
        panelEventos.add(btnCasoVenta);

        // Botón Caso 2: ON_CHRISTMAS_PROMO
        JButton btnCasoNavidad = new JButton("🎄 Disparar: Se acerca Navidad (ON_CHRISTMAS_PROMO - IDs [102, 104])");
        btnCasoNavidad.addActionListener(e -> dispararEventoNavidad());
        panelEventos.add(btnCasoNavidad);

        // Botón Compilar desde JSON de Godot + Ejecutar
        JButton btnCompilarJson = new JButton("⚙️ Compilar JSON de Godot -> Bytecode (GabyCodeCompiler)");
        btnCompilarJson.addActionListener(e -> compilarJsonDesdeGodot());
        panelEventos.add(btnCompilarJson);

        // Botón Seleccionar otro archivo .bytecode
        JButton btnElegirBytecode = new JButton("📂 Seleccionar archivo .bytecode manualmente...");
        btnElegirBytecode.addActionListener(e -> seleccionarArchivoBytecode());
        panelEventos.add(btnElegirBytecode);

        JSplitPane splitSuperior = new JSplitPane(JSplitPane.HORIZONTAL_SPLIT, panelInventario, panelEventos);
        splitSuperior.setDividerLocation(460);

        // 3. Panel Inferior: Consola de Ejecución de la Máquina Virtual
        consolaLog = new JTextArea();
        consolaLog.setEditable(false);
        consolaLog.setBackground(new Color(30, 30, 36));
        consolaLog.setForeground(new Color(220, 255, 220));
        consolaLog.setFont(new Font("Consolas", Font.PLAIN, 13));
        JScrollPane scrollConsola = new JScrollPane(consolaLog);
        scrollConsola.setPreferredSize(new Dimension(1000, 260));
        scrollConsola.setBorder(BorderFactory.createTitledBorder("🖥️ Consola de la Máquina Virtual y Alertas Host"));

        vm.setLoggerCallback(this::agregarLog);

        add(splitSuperior, BorderLayout.CENTER);
        add(scrollConsola, BorderLayout.SOUTH);

        refrescarTablaInventario();
        agregarLog("=== Simulador de Despensa GabyCode Iniciado ===");
        agregarLog("Bytecode activo: " + (rutaBytecodeActual != null ? rutaBytecodeActual.toAbsolutePath() : "Ninguno"));
    }

    private void dispararEscaneoProducto() {
        int index = comboProductoEscaneo.getSelectedIndex();
        int idProd = 101 + index;
        Producto seleccionado = vm.getCatalogoProductos().get(idProd);

        agregarLog("\n------------------------------------------------------------");
        agregarLog("🔔 [EVENT BUS] Evento publicado: ON_PRODUCT_SCANNED -> " + seleccionado);
        Map<String, Object> payload = new HashMap<>();
        payload.put("ProductoActual", seleccionado);
        payload.put("producto_leido", seleccionado);

        eventBus.publicarEvento("ON_PRODUCT_SCANNED", payload, rutaBytecodeActual);
        refrescarTablaInventario();
    }

    private void dispararFinalizarVenta() {
        List<Producto> carrito = new ArrayList<>(Arrays.asList(
                vm.getCatalogoProductos().get(101),
                vm.getCatalogoProductos().get(103)
        ));
        agregarLog("\n------------------------------------------------------------");
        agregarLog("🔔 [EVENT BUS] Evento publicado: ON_SALE_FINISHED -> Carrito: " + carrito);
        Map<String, Object> payload = new HashMap<>();
        payload.put("lista_productos", carrito);

        eventBus.publicarEvento("ON_SALE_FINISHED", payload, rutaBytecodeActual);
        refrescarTablaInventario();
    }

    private void dispararEventoNavidad() {
        List<Integer> idsNavidad = new ArrayList<>(Arrays.asList(102, 104));
        agregarLog("\n------------------------------------------------------------");
        agregarLog("🔔 [EVENT BUS] Evento publicado: ON_CHRISTMAS_PROMO -> IDs en promoción: " + idsNavidad);
        Map<String, Object> payload = new HashMap<>();
        payload.put("lista_ids_descuento", idsNavidad);

        eventBus.publicarEvento("ON_CHRISTMAS_PROMO", payload, rutaBytecodeActual);
        refrescarTablaInventario();
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

            // Buscar el jar de Gson en el repositorio local de Maven del usuario o ejecutar el compilador
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
            agregarLog("\n⚙️ [Compilador Invocado]:\n" + salidaCompilador);
        } catch (Exception ex) {
            agregarLog("⚠️ Error al invocar el compilador automáticamente: " + ex.getMessage());
        }
    }

    private void seleccionarArchivoBytecode() {
        JFileChooser chooser = new JFileChooser(new File("."));
        if (chooser.showOpenDialog(this) == JFileChooser.APPROVE_OPTION) {
            rutaBytecodeActual = chooser.getSelectedFile().toPath();
            agregarLog("\n📂 Nuevo archivo Bytecode seleccionado: " + rutaBytecodeActual.toAbsolutePath());
        }
    }

    private void refrescarTablaInventario() {
        modeloTabla.setRowCount(0);
        for (Producto p : vm.getCatalogoProductos().values()) {
            modeloTabla.addRow(new Object[]{p.id, p.nombre, String.format("$ %.2f", p.precio), p.stock});
        }
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
