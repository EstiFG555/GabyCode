/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 */

package com.mycompany.jvmgabi;


/**
 *
 * @author Agustina
 */
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.List;

public class JVMGabi {

    public static void main(String[] args)throws IOException {
        List<String> programa = Files.readAllLines(Paths.get("C:\\Users\\Agustina\\OneDrive\\Documentos\\NetBeansProjects\\JVMGabi\\Documento.GabyCode.txt"));   
        MaquinaVirtual vm = new MaquinaVirtual();
        vm.ejecutar(programa);
    }
}
