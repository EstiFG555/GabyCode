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
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

public class Grafo {

    @SerializedName("variables_locales")
    private List<Map<String, Object>> variablesLocales;

    @SerializedName("nodos")
    private List<Nodo> nodos;

    public Grafo() {
        this.variablesLocales = new ArrayList<>();
        this.nodos = new ArrayList<>();
    }

    public List<Map<String, Object>> getVariablesLocales() {
        return variablesLocales;
    }

    public void setVariablesLocales(List<Map<String, Object>> variablesLocales) {
        this.variablesLocales = variablesLocales;
    }

    public List<Nodo> getNodos() {
        return nodos;
    }

    public void setNodos(List<Nodo> nodos) {
        this.nodos = nodos;
    }
}