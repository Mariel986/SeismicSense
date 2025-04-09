using System.Collections.Generic;
using UnityEngine;

public class SeismicSense : MonoBehaviour
{
    public Shader seismicShader;

    public Material seismicMaterial;
    public float speed = 1f;
    public float timeLimit = 10f;
    [Range(0f, 10f)]
    public float range = 2f;

    private List<float> _timer;
    private List<Vector4> _seismicCenter;
    private int _active = 0;
    private int _maxWaves = 20;

    void OnEnable()
    {
        _timer = new List<float>();
        _seismicCenter = new List<Vector4>();

        for(int i = 0; i < _maxWaves; i++)
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
                AddWave(hitInfo.point);
            }
        }

        UpdateWaves();
    }

    public void AddWave(Vector3 point)
    {
        _seismicCenter.RemoveAt(_maxWaves - 1);
        _timer.RemoveAt(_maxWaves - 1);
        _seismicCenter.Insert(0, new Vector4(point.x, point.y, point.z, 1.0f));
        _timer.Insert(0, 0.0f);
        if(_active < _maxWaves) _active++;
    }

    void UpdateWaves()
    {
        for(int i = 0; i < _timer.Count; i++)
        {
            _timer[i] += Time.deltaTime * speed;
        }

        if(_active > 0 && _timer[_active - 1] > timeLimit)
        {
            _active--;
        }

        seismicMaterial.SetInt("_Active", _active);
        seismicMaterial.SetFloat("_Range",range);
        if(_active > 0)
        {
            seismicMaterial.SetFloatArray("_Timer", _timer);
            seismicMaterial.SetVectorArray("_SeismicCenter", _seismicCenter);
        }
    }

    void OnDisable()
    {
        _timer = null;
        _seismicCenter = null;
    }

}
