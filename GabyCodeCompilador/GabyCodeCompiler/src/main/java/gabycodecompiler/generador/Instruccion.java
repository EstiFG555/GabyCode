/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Class.java to edit this template
 */
package gabycodecompiler.generador;

/**
 *
 * @author facu
 */
public class Instruccion {
    
    private CodigoOperacion codigoOperacion;
    private Object operando; //Opcional(ej: "ProductoActual". 5, "SHOW_ALERT" o null)
    
    public Instruccion(CodigoOperacion codigoOperacion){
        this.codigoOperacion = codigoOperacion;
        this.operando = null;
    }
    
    public Instruccion(CodigoOperacion codigoOperacion, Object operando){
        this.codigoOperacion = codigoOperacion;
        this.operando = operando;
    }
    
    public CodigoOperacion getCodigoOperacion() {
        return codigoOperacion;
    }

    public void setCodigoOperacion(CodigoOperacion codigoOperacion) {
        this.codigoOperacion = codigoOperacion;
    }

    public Object getOperando() {
        return operando;
    }

    public void setOperando(Object operando) {
        this.operando = operando;
    }
    
    @Override
    public String toString(){
        if(operando != null){
            return codigoOperacion.name()+""+operando;
        }
        return codigoOperacion.name();
    }
}
