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
import java.util.List;

public class JVMGabi {

    public static void main(String[] args) throws IOException {
        if (args != null && args.length > 0 && !args[0].isBlank()) {
            File f = new File(args[0]);
            if (f.exists()) {
                List<String> programa = Files.readAllLines(f.toPath());
                MaquinaVirtual vm = new MaquinaVirtual();
                vm.ejecutar(programa);
                return;
            }
        }
        // Por defecto, abre la interfaz gráfica interactiva de la Despensa
        SimuladorDespensaUI.iniciarVentana();
    }
}
