/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Class.java to edit this template
 */
package gabycodecompiler.modelo;

/**
 *
 * @author facu
 */
import com.google.gson.annotations.SerializedName;
import java.util.List;
import java.util.Map;

public class Nodo {

    private int id;
    private String tipo; // ej: "CONTROL", "ACCION", "OPERACION"

    @SerializedName("operacion")
    private String operacion; // ej: "IF_ELSE", "LESS_THAN", "SHOW_ALERT"

    // --- Salidas de ejecución como lista de IDs numéricos --- 
    @SerializedName("salidas_ejecucion") 
    private List<Integer> salidasEjecucion;
    
    // --- Clave estandarizada a datos_entrada --- 
    @SerializedName("datos_entrada")
    private Map<String, EntradaDato> datosEntrada;

    public Nodo() {
    }

    public int getId() {
        return id;
    }

    public void setId(int id) {
        this.id = id;
    }

    public String getTipo() {
        return tipo;
    }

    public void setTipo(String tipo) {
        this.tipo = tipo;
    }

    public String getOperacion() {
        return operacion;
    }

    public void setOperacion(String operacion) {
        this.operacion = operacion;
    }

    public List<Integer> getSalidasEjecucion() {
        return salidasEjecucion;
    }

    public void setSalidasEjecucion(List<Integer> salidasEjecucion) {
        this.salidasEjecucion = salidasEjecucion;
    }

    public Map<String, EntradaDato> getDatosEntrada() {
        return datosEntrada;
    }

    public void setDatosEntrada(Map<String, EntradaDato> datosEntrada) {
        this.datosEntrada = datosEntrada;
    }
    
}
