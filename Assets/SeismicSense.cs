using System.Collections.Generic;
using UnityEngine;

public class SeismicSense : MonoBehaviour
{
    public Shader seismicShader;

    public Material seismicMaterial;
    public float speed = 1f;
    public float timeLimit = 10f;

    private List<float> _timer;
    private List<Vector4> _seismicCenter;
    private int _active = 0;

    void OnEnable()
    {
        _timer = new List<float>();
        _seismicCenter = new List<Vector4>();

        for(int i = 0; i < 5; i++)
        {
            _seismicCenter.Add(Vector4.zero);
            _timer.Add(0.0f);
        }
        
        seismicMaterial.SetInt("_Active", _active);
        seismicMaterial.SetFloatArray("_Timer", _timer);
        seismicMaterial.SetVectorArray("_SeismicCenter", _seismicCenter);
    }

    void Update()
    {
        if(Input.GetMouseButtonDown(0))
        {
            Ray ray = Camera.main.ScreenPointToRay(Input.mousePosition);
            RaycastHit hitInfo;
            if(Physics.Raycast(ray, out hitInfo))
            {
                _seismicCenter.RemoveAt(4);
                _timer.RemoveAt(4);
                _seismicCenter.Insert(0, new Vector4(hitInfo.point.x, hitInfo.point.y, hitInfo.point.z, 1.0f));
                _timer.Insert(0, 0.0f);
                if(_active < 5) _active++;
                Debug.Log(_timer);
            }
        }
        Debug.Log(_active);

        for(int i = 0; i < _timer.Count; i++)
        {
            _timer[i] += Time.deltaTime * speed;
        }

        if(_active > 0 && _timer[_active - 1] > timeLimit)
        {
            _active--;
        }

        seismicMaterial.SetInt("_Active", _active);
        if(_active > 0)
        {
            seismicMaterial.SetFloatArray("_Timer", _timer);
            seismicMaterial.SetVectorArray("_SeismicCenter", _seismicCenter);
        }
    }

    void OnDisable()
    {
    }

    void OnValidate()
    {
        OnDisable();
        OnEnable();     
    }
}
