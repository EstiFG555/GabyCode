/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Class.java to edit this template
 */
package gabycodecompiler.modelo;

import com.google.gson.annotations.SerializedName;

/**
 *
 * @author facu
 */
public class EntradaDato {

    @SerializedName("fuente")
    private String fuente; // "LITERAL" o "REFERENCIA NODO" o "VARIABLE"
    
    private Object valor; // Si es LITERAL (ej: 5.0, "Stock bajo")
    
    private String nombre; // Si es VARIABLE (como "ProductoActual")
    
    @SerializedName("id_origen")
    private Integer idOrigen; //Si es REFERENCIA NODO (como "2")
    
    @SerializedName("puerto")
    private String puerto; //como resultado
    
    public EntradaDato(){}

    public String getFuente() {
        return fuente;
    }

    public void setFuente(String fuente) {
        this.fuente = fuente;
    }

    public Object getValor() {
        return valor;
    }

    public void setValor(Object valor) {
        this.valor = valor;
    }

    public String getNombre() {
        return nombre;
    }

    public void setNombre(String nombre) {
        this.nombre = nombre;
    }

    public Integer getIdOrigen() {
        return idOrigen;
    }

    public void setIdOrigen(Integer idOrigen) {
        this.idOrigen = idOrigen;
    }

    public String getPuerto() {
        return puerto;
    }

    public void setPuerto(String puerto) {
        this.puerto = puerto;
    }
    
}
